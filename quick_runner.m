function quick_runner(model_name, exp_name, path_to_source_code, seed)

    arguments
        model_name
        exp_name
        path_to_source_code
        seed = 'null'
    end

    %% --- paths ---
    inputs_root = fullfile(path_to_source_code, 'inputs');
    src_inputs  = fullfile(inputs_root, 'Inputs2Copy');

    if exp_name == ""
        target_dir  = fullfile(inputs_root, "example_inputs", model_name);
        outputs_dir = fullfile(path_to_source_code, 'outputs', model_name);
    else
        target_dir  = fullfile(inputs_root, "example_inputs", model_name, exp_name);
        outputs_dir = fullfile(path_to_source_code, 'outputs', model_name, exp_name);
    end

    %% --- safety checks ---
    assert(isfolder(target_dir), 'Target directory does not exist: %s', target_dir);
    assert(isfolder(src_inputs), 'Inputs2Copy directory missing: %s', src_inputs);

    %% --- copy input files ---
    copyfile(fullfile(src_inputs, 'build_inputs_robust.m'), target_dir);

    optional_file = fullfile(src_inputs, 'optional_inputs.m');
    if isfile(optional_file)
        copyfile(optional_file, target_dir);
    end

    %% --- ensure output directory exists ---
    if ~isfolder(outputs_dir)
        mkdir(outputs_dir);
    end

    %% --- seed ---
    if ~isstring(seed)
        rng(seed, 'twister');
    end

    %% =========================
    %  CLEAN PATH MANAGEMENT
    %% =========================
    original_path = path;
    cleanup_path = onCleanup(@() path(original_path));

    % Add paths
    addpath(path_to_source_code);                    % main code
    addpath(genpath(fullfile(path_to_source_code, 'static_tables')));

    % Add target_dir so scripts can run without cd
    addpath(target_dir);

    %% --- run input scripts ---

    % Load required data tables for build inputs
    component_attributes = readtable(fullfile(path_to_source_code, "static_tables/component_attributes.csv"), 'VariableNamingRule', 'preserve');
    subsystems = readtable(fullfile(path_to_source_code, "static_tables/subsystems.csv"), 'VariableNamingRule', 'preserve');
    damage_state_attribute_mapping = readtable(fullfile(path_to_source_code, "static_tables/damage_state_attribute_mapping.csv"), 'VariableNamingRule', 'preserve');
    tenant_function_requirements = readtable(fullfile(path_to_source_code, "static_tables/tenant_function_requirements.csv"), 'VariableNamingRule', 'preserve');

    % if comp_population doesn't exist, build it from xlsx
    % workaround to sum all duplicate variable names

    if ~isfile(fullfile(target_dir, 'comp_population.csv'))
        T = readtable(fullfile(target_dir, 'comp_population.xlsx'), 'VariableNamingRule', 'preserve');
        renamed_columns = T.Properties.VariableNames;
        original_columns = cell(size(renamed_columns));
        for k = 1:numel(renamed_columns)
            name = renamed_columns{k}; % Use curly braces to get the data inside
            if contains(name, '_')
                original_columns{k} = extractBefore(name, "_");
            else
                original_columns{k} = name;
            end
        end

        % --- group by original names ---
        [unique_names, ~, idx] = unique(original_columns, 'stable');
    
        % --- sum duplicate columns ---
        data = T{:,:};   % numeric matrix (assumes numeric data)
    
        T_sum = zeros(size(data,1), numel(unique_names));
    
        for i = 1:numel(unique_names)
            cols = (idx == i);
            T_sum(:, i) = sum(data(:, cols), 2, 'omitnan');
        end
        % --- rebuild table ---
        T_out = array2table(T_sum, 'VariableNames', unique_names);
        writetable(T_out, fullfile(target_dir, 'comp_population.csv'));
    end
    run(fullfile(target_dir, 'optional_inputs.m'));
    run(fullfile(target_dir, 'build_inputs_robust.m'));

    %% --- load generated inputs ---
    simulated_inputs_path = fullfile(target_dir, 'simulated_inputs.mat');
    S = load(simulated_inputs_path);

    % unpack required variables explicitly
    damage = S.damage;
    damage_consequences = S.damage_consequences;
    building_model = S.building_model;
    tenant_units = S.tenant_units;
    impedance_options = S.impedance_options;
    repair_time_options = S.repair_time_options;
    functionality = S.functionality;
    functionality_options = S.functionality_options;

    %% --- load static tables ---
    systems = readtable(fullfile(path_to_source_code, "static_tables/systems.csv"), 'VariableNamingRule', 'preserve');
    subsystems = readtable(fullfile(path_to_source_code, "static_tables/subsystems.csv"), 'VariableNamingRule', 'preserve');
    impeding_factor_medians = readtable(fullfile(path_to_source_code, "static_tables/impeding_factors.csv"), 'VariableNamingRule', 'preserve');
    tmp_repair_class = readtable(fullfile(path_to_source_code, "static_tables/temp_repair_class.csv"), 'VariableNamingRule', 'preserve');

    %% --- run analysis ---
    [functionality, damage_consequences] = main_PBEErecovery( ...
        damage, damage_consequences, ...
        building_model, tenant_units, systems, subsystems, tmp_repair_class, ...
        impedance_options, impeding_factor_medians, repair_time_options, ...
        functionality, functionality_options);

    %% --- save outputs ---
    if ~isstring(seed)
        out_file_json = fullfile(outputs_dir, sprintf('recovery_outputs_%d.json', seed));
        out_file_mat  = fullfile(outputs_dir, sprintf('recovery_outputs_%d.mat', seed));
    else
        out_file_json = fullfile(outputs_dir, 'recovery_outputs.json');
        out_file_mat  = fullfile(outputs_dir, 'recovery_outputs.mat');
    end

    save(out_file_mat, 'functionality');

    fprintf('Recovery assessment of model %s complete\n', model_name)

    % JSON export
    data = load(out_file_mat);
    jsonText = jsonencode(data);

    fid = fopen(out_file_json, 'w');
    assert(fid ~= -1, 'Cannot open file: %s', out_file_json);

    fwrite(fid, jsonText, 'char');
    fclose(fid);

end