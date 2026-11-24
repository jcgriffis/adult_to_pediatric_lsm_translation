function out_dir = run_ui_lang_reg_models(model_spec, outcome, modality, stroke_flag, pos_only)

% Convert strings to indicators
if strcmp(stroke_flag, '1')
    stroke_flag = 1;
else
    stroke_flag = 0;
end
if strcmp(pos_only, '1')
    pos_only = 1;
else
    pos_only = 0;
end

% Output directory
suffix = '';
if stroke_flag == 1
    suffix = [suffix '_stroke'];
else
    suffix = [suffix '_all'];
end
if pos_only == 1
    suffix = [suffix '_pos_only'];
end
out_dir = fullfile('/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/registry_models/language', outcome, [model_spec '_all_' modality suffix '_ui']);

if ~isfile(fullfile(out_dir, 'model_results.mat'))

    % Add paths to relevant functions
    cfg.model_dir = '/Shared/boeslab/Users/jcgriffis/ibb_modeling_toolkit/model_code';
    addpath(fullfile(cfg.model_dir, 'common')); 
    
    % Specify data modality and supply brain mask
    cfg.modality = 'lesion';
    cfg.mask_path = fullfile('/Shared/boeslab/Atlas/volumetric/MNI152/2mm/masks/wholecb_maskSmooth.nii.gz'); 
    
    % Specify path to CSV containing study IDs and behavioral scores
    beh_csv = readtable('/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/behavior/registry_lang_data.csv');
    id_col = 'study_id';
    if stroke_flag == 1 % Drop non-stroke if desired
        beh_csv = beh_csv(beh_csv.etiology >= 22,:);
    end
    
    % Specify general modeling options
    cfg.model_spec = model_spec;
    cfg.fit_explanatory_model = 1; 
    cfg.optimize_hyperparams = 1; 
    cfg.cross_validation = 1;
    cfg.bootstrap = 0; 
    cfg.permutation = 0; 
    
    % Initialize cfg file and set data inclusion thresholds
    cfg = get_default_model_cfg(cfg); 
    cfg.min_obs = 1;
    cfg.freq_thresh = 1;
    if pos_only == 1
        cfg.pos_only = 1;
    end
    % Behavioral column
    beh_col = outcome;
    
    % Get lesion and outcome data
    registry_flag = 1; 
    lesion_dir = '/Shared/boeslab/Data/Lesion/Iowa/Registry/lesionMasks/Chronic/MNI152/2mm';
    cfg = get_and_format_lesion_data(beh_csv, id_col, beh_col, registry_flag, lesion_dir, cfg);    

    % Invert outcomes so positive weights reflect association with impairment
    cfg.Y = cfg.Y.*-1;
           
    % Hyper-parameter optimization
    cfg.hp_opt.cv_type = 'KFold'; 
    cfg.hp_opt.folds = 5; 
    cfg.hp_opt.repeats = 5;
    
    % Cross-validation
    cfg.cv.cv_type = 'KFold'; 
    cfg.cv.folds = 5; 
    cfg.cv.repeats = 5; 
    cfg.cv.stacked_model = 1; 

    % Stratification
    cfg.strat_var = cfg.Y;
        
    % Specify output directory
    cfg.out_dir = out_dir;
   
    % fit model with CV hyperparameter optimization and selected significance testing
    [model_results] = fit_and_evaluate_model(cfg);
        
    % Write weight maps
    write_model_weight_maps(model_results);
end

end
