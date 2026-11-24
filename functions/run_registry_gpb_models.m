function run_registry_gpb_models(model_spec, outcome, modality, stroke_flag, laterality, flip_flag, pos_only)

% Convert strings to indicators
if strcmp(stroke_flag, '1')
    stroke_flag = 1;
else
    stroke_flag = 0;
end
if strcmp(flip_flag, '1')
    flip_flag = 1;
else
    flip_flag = 0;
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
if flip_flag == 1
    suffix = [suffix '_flip'];
end
if pos_only == 1
    suffix = [suffix '_pos_only'];
end
out_dir = fullfile('/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/registry_models/motor', outcome, [model_spec '_' laterality '_' modality suffix '_ui']);        

if ~isfile(fullfile(out_dir, 'model_results.mat'))

    % Add paths to relevant functions
    cfg.model_dir = '/Shared/boeslab/Users/jcgriffis/ibb_modeling_toolkit/model_code'; 
    addpath(genpath(fullfile(cfg.model_dir, 'common'))); 
    
    % Specify data modality and supply brain mask
    cfg.modality = 'lesion';
    cfg.mask_path = fullfile('/Shared/boeslab/Atlas/volumetric/MNI152/2mm/masks/wholecb_maskSmooth.nii.gz'); 
    mask_img = niftiread(cfg.mask_path);
    cfg.mask_inds = find(mask_img==1);

    % Get Registry dataset
    project_dir = '/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/behavior';
    beh_csv = readtable(fullfile(project_dir, 'registry_gpb_data.csv'), 'Format', 'auto');
    if stroke_flag == 1 % Drop non-stroke if desired
        beh_csv = beh_csv(beh_csv.etiology >= 22,:);
    end        
    
    % Define outcome measures
    if strcmp(laterality, 'lh')
        beh_csv = beh_csv(string(beh_csv.laterality) == 'L',:);
        beh_csv.gpb_dif = beh_csv.lft_t - beh_csv.rt_t;     
    elseif strcmp(laterality, 'rh')
        beh_csv = beh_csv(string(beh_csv.laterality) == 'R',:);
        beh_csv.gpb_dif = beh_csv.rt_t - beh_csv.lft_t;     
    elseif strcmp(laterality, 'uni')
        beh_csv = beh_csv(string(beh_csv.laterality) ~= 'B',:);
        gpb_dif = zeros(length(beh_csv.rt_t),1);
        gpb_dif(strcmp(string(beh_csv.laterality), 'L')) = beh_csv.lft_t(strcmp(string(beh_csv.laterality), 'L'))-beh_csv.rt_t(strcmp(string(beh_csv.laterality), 'L'));
        gpb_dif(strcmp(string(beh_csv.laterality), 'R')) = beh_csv.rt_t(strcmp(string(beh_csv.laterality), 'R'))-beh_csv.lft_t(strcmp(string(beh_csv.laterality), 'R'));        
        beh_csv.gpb_dif = gpb_dif;
    else
        gpb_dif = zeros(length(beh_csv.rt_t),1);
        gpb_dif(strcmp(string(beh_csv.laterality), 'L')) = beh_csv.lft_t(strcmp(string(beh_csv.laterality), 'L'))-beh_csv.rt_t(strcmp(string(beh_csv.laterality), 'L'));
        gpb_dif(strcmp(string(beh_csv.laterality), 'R')) = beh_csv.rt_t(strcmp(string(beh_csv.laterality), 'R'))-beh_csv.lft_t(strcmp(string(beh_csv.laterality), 'R'));
        gpb_dif(strcmp(string(beh_csv.laterality), 'B')) = max([beh_csv.lft_t(strcmp(string(beh_csv.laterality), 'B')), beh_csv.rt_t(strcmp(string(beh_csv.laterality), 'B'))],[],2) - min([beh_csv.lft_t(strcmp(string(beh_csv.laterality), 'B')), beh_csv.rt_t(strcmp(string(beh_csv.laterality), 'B'))],[],2);
        beh_csv.gpb_dif = gpb_dif;
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
    
    % Get lesion path
    if flip_flag == 0
        id_col = 'lesion_path';
    else
        id_col = 'lesion_flip_plus_native_path';
    end   
    % Get imaging data
    cfg = get_and_format_lesion_data2(beh_csv, id_col, beh_col, cfg);        
       
    % Hyper-parameter optimization
    cfg.hp_opt.cv_type = 'KFold'; 
    cfg.hp_opt.folds = 5; 
    cfg.hp_opt.repeats = 5;
    
    % Cross-validation
    cfg.cv.cv_type = 'KFold'; 
    cfg.cv.folds = 5; 
    cfg.cv.repeats = 5; 
    cfg.cv.permutation = 0; 
    cfg.cv.n_perm = 0; 
    cfg.cv.stacked_model = 1; 
   
    % Stratification
    cfg.strat_var = cfg.Y;    
    
    % Specify output directory
    cfg.out_dir = out_dir;
   
    % fit model with CV hyperparameter optimization and selected significance testing
    [model_results] = fit_and_evaluate_model(cfg);
           
    % Write weight maps
    write_model_weight_maps(model_results);

    % Write out subsetted behavioral CSV
    beh_csv = beh_csv(cfg.include_inds,:);
    cd(cfg.out_dir);
    writetable(beh_csv, 'beh_csv_sm.csv');

end