function out_dir = run_vips_psom_models_cv2(ui_model_path, modality, model_spec, beh_col, ...
    min_stroke_age, min_test_age, min_test_interval, min_freq, min_freq_stack, recur_exc, pos_only)

% Output directory
if pos_only == 1 && contains(modality, 'lesion')
    suffix = '_pos_only';
else
    suffix = '';
end
if contains(modality, 'vips')
    suffix = [suffix '_stacked_vips'];
end
if recur_exc == 0 
    out_dir = fullfile('/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/vips_psom_models/results/',...
        ['min_stroke_' num2str(min_stroke_age) '_min_test_' num2str(min_test_age) '_min_interval_' num2str(min_test_interval) '_min_freq_' num2str(min_freq)],...
        beh_col, [model_spec '_' modality suffix]);
else
    out_dir = fullfile('/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/vips_psom_models/results/',...
        ['min_stroke_' num2str(min_stroke_age) '_min_test_' num2str(min_test_age) '_min_interval_' num2str(min_test_interval) '_min_freq_' num2str(min_freq) '_recur_exc'],...
        beh_col, [model_spec '_' modality suffix]);
end
cfg.out_dir = out_dir;

if ~isfile(fullfile(cfg.out_dir, 'model_results.mat'))

    % Add paths to relevant functions and mask
    cfg.model_dir = '/Shared/boeslab/Users/jcgriffis/ibb_modeling_toolkit/model_code'; 
    addpath(genpath(fullfile(cfg.model_dir, 'common'))); 
    cfg.mask_path = fullfile('/Shared/boeslab/Atlas/volumetric/MNI152/2mm/masks/wholecb_maskSmooth.nii.gz'); 
    
    % Get VIPS dataset
    project_dir = '/Shared/boeslab/Users/jcgriffis/vips_psom_prediction';
    beh_csv = readtable(fullfile(project_dir, 'behavior', 'vips_combined_31226.csv'), 'Format', 'auto');
    if recur_exc == 0
        inc_ind = find(all([beh_csv.stroke_age >= min_stroke_age, beh_csv.test_age >= min_test_age, beh_csv.yrs2test >= min_test_interval, ...
            beh_csv.has_lesion==1],2));    
    else
        inc_ind = find(all([beh_csv.stroke_age >= min_stroke_age, beh_csv.test_age >= min_test_age, beh_csv.yrs2test >= min_test_interval, ...
            beh_csv.has_lesion==1, beh_csv.recur_exc == 0],2));    
    end
    beh_csv = beh_csv(inc_ind,:);

    % Get default model cfg for analysis type
    cfg.model_spec = model_spec;
    if contains(modality, 'lesion')
        cfg.modality = 'lesion';
    else
        cfg.modality = 'other';
    end
    cfg.permutation = 0;
    cfg.bootstrap = 0;
    cfg.cross_validation = 1;
    cfg.optimize_hyperparams = 1;
    cfg.fit_explanatory_model = 1;
    cfg = get_default_model_cfg(cfg);
    if contains(modality, 'clin')
        cfg.min_obs = 0;
    else
        cfg.min_obs = 1;
    end
    if ~contains(modality, 'clin')
        cfg.freq_thresh = min_freq;
    else
        cfg.freq_thresh = min_freq_stack;
    end
    
    % Make output directory
    if recur_exc == 0
        result_dir = ['/min_stroke_' num2str(min_stroke_age) '_min_test_' num2str(min_test_age) '_min_interval_' num2str(min_test_interval) '_min_freq_' num2str(min_freq)];   
    else
        result_dir = ['/min_stroke_' num2str(min_stroke_age) '_min_test_' num2str(min_test_age) '_min_interval_' num2str(min_test_interval) '_min_freq_' num2str(min_freq) '_recur_exc'];   
    end        

    % Get data
    if contains(modality, 'lesion') % Lesion location - pediatric model

        if contains(beh_col, 'motor') 
            lesion_dir = '/Shared/boeslab/Data/Lesion/SickKids/lesionMasksNativePlusFlipped/MNI152/2mm';
        else
            lesion_dir = '/Shared/boeslab/Data/Lesion/SickKids/lesionMasks/MNI152/2mm';
        end
        cfg = get_and_format_lesion_data(beh_csv, id_col, beh_col, 0, lesion_dir, cfg);         

    elseif strcmp(modality, 'base') % base model - pediatric model

        cfg.X = [beh_csv.lh_vol, beh_csv.rh_vol, beh_csv.stroke_age, beh_csv.yrs2test];
        cfg.include_inds = 1:1:size(cfg.X,1);
        cfg.include_subs = beh_csv.ipssid;
        cfg.Y = beh_csv.(beh_col);     
        cfg.standardize = 1;
        cfg.standardize_method = 'range';
        cfg.standardize_type = [0,1];        

    elseif strcmp(modality, 'base_int') % base model with interaction - pediatric model

        cfg.X = [beh_csv.lh_vol, beh_csv.rh_vol, beh_csv.stroke_age, beh_csv.yrs2test, beh_csv.lh_vol.*beh_csv.stroke_age];
        cfg.include_inds = 1:1:size(cfg.X,1);
        cfg.include_subs = beh_csv.ipssid;
        cfg.Y = beh_csv.(beh_col);     
        cfg.standardize = 1;
        cfg.standardize_method = 'range';
        cfg.standardize_type = [0,1];                

    elseif strcmp(modality, 'expanded_full') % expanded with full adult model predictions

        if contains(beh_col, 'lang')
            load(fullfile(ui_model_path, 'vips_preds_mae_token.mat'), 'll_pred');        
        elseif contains(beh_col, 'motor')
            load(fullfile(ui_model_path, 'vips_preds_gpb_dif.mat'), 'll_pred');           
        end        
        cfg.X = [ll_pred(inc_ind), beh_csv.lh_vol, beh_csv.rh_vol, beh_csv.stroke_age, beh_csv.yrs2test];
        cfg.include_inds = 1:1:size(cfg.X,1);
        cfg.include_subs = beh_csv.ipssid;
        cfg.Y = beh_csv.(beh_col);     
        cfg.standardize = 1;
        cfg.standardize_method = 'range';
        cfg.standardize_type = [0,1];        

    elseif strcmp(modality, 'expanded_pos') || strcmp(modality, 'expanded_pos_int') % expanded with positive-weight adult model predictions with or without interaction

        if contains(beh_col, 'lang')
            load(fullfile(ui_model_path, 'vips_preds_mae_token.mat'), 'll_pos');        
        elseif contains(beh_col, 'motor')
            load(fullfile(ui_model_path, 'vips_preds_gpb_dif.mat'), 'll_pos');           
        end        
        if strcmp(modality, 'expanded_pos') % include interaction if not standard expanded model
            cfg.X = [ll_pos(inc_ind), beh_csv.lh_vol, beh_csv.rh_vol, beh_csv.stroke_age, beh_csv.yrs2test];
        else
            cfg.X = [ll_pos(inc_ind), beh_csv.lh_vol, beh_csv.rh_vol, beh_csv.stroke_age, beh_csv.yrs2test, zscore(beh_csv.lh_vol).*beh_csv.stroke_age];
        end            
        cfg.include_inds = 1:1:size(cfg.X,1);
        cfg.include_subs = beh_csv.ipssid;
        cfg.Y = beh_csv.(beh_col);     
        cfg.standardize = 1;
        cfg.standardize_method = 'range';
        cfg.standardize_type = [0,1];                
  
    elseif contains(modality, 'vips')
        
        if ~contains(modality, '_int') % include interaction if indicated
           cfg.X = [beh_csv.lh_vol, beh_csv.rh_vol, beh_csv.stroke_age, beh_csv.yrs2test];
        else
           cfg.X= [beh_csv.lh_vol, beh_csv.rh_vol, beh_csv.stroke_age, beh_csv.yrs2test, zscore(beh_csv.lh_vol).*beh_csv.stroke_age];
        end          
        
        cfg.include_inds = 1:1:size(cfg.X,1);
        cfg.include_subs = beh_csv.ipssid;
        cfg.Y = beh_csv.(beh_col);     
        cfg.standardize = 1;
        cfg.standardize_method = 'range';
        cfg.standardize_type = [0,1];            
       
    end

    % Fix partitions to match LSM model for base/expanded models
    if ~contains(modality, 'lesion')
        if contains(modality, 'pos') % use positive model weights only to generate predictions if indicated 
            model_path = ['/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/vips_psom_models/results' result_dir '/' char(beh_col) '/plsr_lesion_d0_pos_only'];
            load(fullfile(model_path, 'cv_results.mat'));      
        else
            model_path = ['/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/vips_psom_models/results' result_dir '/' char(beh_col) '/plsr_lesion_d0'];
            load(fullfile(model_path, 'cv_results.mat'));      
        end    
        cfg.cv.partitions.train_set = cv_results.train_set;
        cfg.cv.partitions.test_set = cv_results.test_set;    

        % Add stacked lesion predictions for VIPS models
        if contains(modality, 'vips')
            cfg.cv.stack_preds{1} = cv_results.all.pred_y;
        end        
        clear cv_results
    end

    % Recode outcome if regression model to have equal intervals between levels if not a classification model, binarize if it is
    if cfg.cat_Y == 0
        Y = zeros(length(cfg.Y),1);
        Y(cfg.Y==0)=0;
        Y(cfg.Y==0.5)=1;
        Y(cfg.Y==1)=2;
        Y(cfg.Y==2)=3;
        cfg.Y = Y;
    else
        cfg.Y(cfg.Y < 1)=-1;
        cfg.Y(cfg.Y > 0)=1;           
    end

    % Stratification for CV
    if cfg.cat_Y == 1
        cfg.strat_var = cfg.Y; 
        cfg.strat_groups = categorical(cfg.Y); 
    else
        cfg.strat_var = cfg.Y;
        cfg.strat_groups = categorical(cfg.Y <= 1);
    end
    
    % Set misclassification costs if classifier
    if cfg.cat_Y == 1
        n_neg = numel(find(cfg.Y==-1));
        n_pos = numel(find(cfg.Y==1));
        cfg.cost = [0, n_neg./n_pos; 1, 0];
    end
    
    % Set flag for using only positive coefficients in CV if lesion model and pos_only option selected
    if pos_only == 1 && strcmp(modality, 'lesion_d0')
        cfg.pos_only = 1;
    end

    % Hyper-parameter optimization
    cfg.hp_opt.cv_type = 'KFold'; 
    cfg.hp_opt.folds = 5; 
    cfg.hp_opt.repeats = 5;
    
    % Cross-validation
    cfg.cv.cv_type = 'KFold'; 
    cfg.cv.folds = 5; 
    cfg.cv.repeats = 5;  
    cfg.cv.stacked_model = 1; 
    
    % Run analysis     
    model_results = fit_and_evaluate_model(cfg);

    % Write maps
    if contains(modality, 'lesion') && cfg.fit_explanatory_model == 1
        write_model_weight_maps(model_results);
    end
    
end
end