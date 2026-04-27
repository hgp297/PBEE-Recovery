% This script facilitates the performance based functional recovery and
% reoccupancy assessment of a single building for a single intensity level

% Input data consists of building model info and simulated component-level
% damage and conesequence data for a suite of realizations, likely assessed
% as part of a FEMA P-58 analysis. Inputs are read in as matlab variables
% direclty from matlab data files, as well as loaded from csvs in the
% static_tables directory.

% Output data is saved to a specified outputs directory and is saved into a
% single matlab variable as at matlab data file.

clear
close all
clc 
rehash

%% Define User Inputs
% model_name = 'haseltonRCMF_4story'; % Name of the model;
exp_name = "";
% model_name = 'haseltonRCMF_12story'; % Name of the model;
% model_name = 'ICSB'; % Name of the model;
model_name = 'RCSW_1story'; % Name of the model;
                     % inputs are expected to be in a directory with this name
                     % outputs will save to a directory with this name

path_to_matcode = fullfile('.');

seed = 985;
% quick_runner(model_name, exp_name, path_to_matcode, seed)


path_to_matcode = fullfile('.');
run_all_models(path_to_matcode)
%% all folders

function run_all_models(path_to_source_code)

    inputs_root = fullfile(path_to_source_code, 'inputs', 'example_inputs');

    model_dirs = dir(inputs_root);
    model_dirs = model_dirs([model_dirs.isdir]);

    % remove . .. and Inputs2Copy
    model_dirs = model_dirs(~ismember({model_dirs.name}, {'.', '..'}));

    for m = 1:length(model_dirs)
        model_name = model_dirs(m).name;
        disp(model_name)

        model_path = fullfile(inputs_root, model_name);
        exp_dirs = dir(model_path);
        exp_dirs = exp_dirs([exp_dirs.isdir]);
        exp_dirs = exp_dirs(~ismember({exp_dirs.name}, {'.', '..'}));

        for e = 1:length(exp_dirs)
            exp_name = exp_dirs(e).name;

            fprintf('Running %s / %s\n', model_name, exp_name);

            for seed = 1:20
                fprintf('  Seed %d\n', seed);
                quick_runner(model_name, exp_name, path_to_source_code, seed);

%                 try
%                     quick_runner(model_name, exp_name, path_to_source_code, seed);
%                 catch ME
%                     warning('Failed: %s / %s / seed %d\n%s', ...
%                         model_name, exp_name, seed, ME.message);
%                 end
            end
        end
    end
end

