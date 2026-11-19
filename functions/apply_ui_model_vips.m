function [ll_pred, ll_pos, cv_pred] = apply_ui_model_vips(outcome, model_path, cfg, beh_csv, get_vips_preds, vips_outcome, min_stroke_age, min_test_age, min_test_interval, min_freq, recur_exc, pos_only)

    % Add paths to relevant functions
    model_dir = '/Shared/boeslab/Users/jcgriffis/ibb_modeling_toolkit/model_code';
    addpath(genpath(fullfile(model_dir, 'common'))); 
    
    % Model results
    disp(['Applying model for ' outcome]);
    load(fullfile(model_path, 'model_results.mat'));
       
    % Get predictions for test set using trained model
    ll_pred = predict_new(model_results, cfg.X); 

    % Get predictions using positive weights only
    X = cfg.X(:,model_results.X_ind);
    ll_pos = X(:, model_results.coeff > 0)*(model_results.coeff(model_results.coeff > 0));
    
    % Load VIPS predictions if indicated
    if recur_exc == 0
        vips_folder = ['min_stroke_' num2str(min_stroke_age) '_min_test_' num2str(min_test_age) '_min_interval_' num2str(min_test_interval) '_min_freq_' num2str(min_freq)];
    else
        vips_folder = ['min_stroke_' num2str(min_stroke_age) '_min_test_' num2str(min_test_age) '_min_interval_' num2str(min_test_interval) '_min_freq_' num2str(min_freq) '_recur_exc'];
    end
    if get_vips_preds == 1
        if ~strcmp(outcome, 'gpb_dif')
            if pos_only == 1
                model_path_vips = ['/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/vips_psom_models/results/' vips_folder '/' char(vips_outcome) '/plsr_lesion_d0_pos_only'];
            else
                model_path_vips = ['/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/vips_psom_models/results/' vips_folder '/' char(vips_outcome) '/plsr_lesion_d0'];
            end                
            load(fullfile(model_path_vips, 'cv_results.mat'));        
        elseif strcmp(outcome, 'gpb_dif')
            if pos_only == 1
                model_path_vips = ['/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/vips_psom_models/results/' vips_folder '/' char(vips_outcome) '/plsr_lesion_d0_pos_only'];
            else
                model_path_vips = ['/Shared/boeslab/Users/jcgriffis/vips_psom_prediction/vips_psom_models/results/' vips_folder '/' char(vips_outcome) '/plsr_lesion_d0'];
            end                
            load(fullfile(model_path_vips, 'cv_results.mat'));        
        end    
        cv_pred = nanmean(cv_results.all.pred_y,2); % average test fold predictions across repetitions
    else
        cv_pred = [];
    end

    % Make table
    t = table();
    t.study_id = beh_csv.orig_id;
    t.ll_pred = ll_pred;
    t.ll_pos = ll_pos;

    % Save table
    out_name = ['vips_preds_' char(outcome) '.csv'];
    pred_file_name = ['vips_preds_' char(outcome) '.mat'];
    cd(model_path);
    writetable(t, out_name)
    save(pred_file_name, "ll_pred", "ll_pos","cv_pred", "cfg", "beh_csv");

end