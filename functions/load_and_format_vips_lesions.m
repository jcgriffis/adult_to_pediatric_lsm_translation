function [cfg, beh_csv] = load_and_format_vips_lesions(beh_col)

    % Add paths to relevant functions
    model_dir = '/Shared/boeslab/Users/jcgriffis/ibb_modeling_toolkit/model_code';
    addpath(genpath(fullfile(model_dir, 'common'))); 
    
    % Load behavioral dataset
    project_dir = '/Shared/boeslab/Users/jcgriffis/vips_psom_prediction';
    beh_csv = readtable(fullfile(project_dir, 'behavior/vips_combined_31226.csv'), 'format', 'auto');
    beh_csv = beh_csv(beh_csv.has_lesion == 1, :);
    id_col = 'orig_id';
    
    % Specify data modality and supply brain mask
    cfg.model_dir = model_dir;        
    cfg.modality = 'other'; 
    
    % Load brain mask amd get indices
    cfg.mask_path = fullfile('/Shared/boeslab/Atlas/volumetric/MNI152/2mm/masks/wholecb_maskSmooth.nii.gz'); 
    mask = niftiread(cfg.mask_path);
    mask(isnan(mask))=0;
    cfg.mask_inds = find(mask); % get map indices for non-zero voxels
    
    % Get imaging data
    if strcmp(beh_col, 'contra_motor') || strcmp(beh_col, 'worst_motor')
        lesion_dir = '/Shared/boeslab/Data/Lesion/SickKids/lesionMasksNativePlusFlipped/MNI152/2mm';
    else
        lesion_dir = '/Shared/boeslab/Data/Lesion/SickKids/lesionMasks/MNI152/2mm';
    end
    cfg = get_and_format_lesion_data(beh_csv, id_col, 'has_lesion', 0, lesion_dir, cfg); 

end