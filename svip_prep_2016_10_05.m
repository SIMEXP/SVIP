% Copyright (c) Pierre Bellec, 
%   Montreal Neurological Institute, McGill University, 2008-2010.
%   Research Centre of the Montreal Geriatric Institute
%   & Department of Computer Science and Operations Research
%   University of Montreal, Quebec, Canada, 2010-2012
% Maintainer : pierre.bellec@criugm.qc.ca
% See licensing information in the code.
% Keywords : medical imaging, fMRI, preprocessing, pipeline

% Permission is hereby granted, free of charge, to any person obtaining a copy
% of this software and associated documentation files (the "Software"), to deal
% in the Software without restriction, including without limitation the rights
% to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
% copies of the Software, and to permit persons to whom the Software is
% furnished to do so, subject to the following conditions:
%
% The above copyright notice and this permission notice shall be included in
% all copies or substantial portions of the Software.
%
% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
% OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
% THE SOFTWARE.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Setting input/output files %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


clear all

addpath(genpath('/gs/project/gsf-624-aa/quarantaine/niak-boss-0.13.4b/'))


root_path = '/gs/project/gsf-624-aa/simons_vip/';
path_out = '/gs/project/gsf-624-aa/simons_vip/svip_testout_2016_10_06/';

%for i in * ; do echo mv $i ${i/15/s15}; done |sh
%for i in * ; do echo mv $i ${i/14/s14}; done |sh
%for i in *; do echo mv $i ${i/./_}; done |sh

%anat4 = MEMPRAGE or  tfl_mgh_multiecho_3D_1mm_iso_MGHprotocol (four echo-times)
%anat_RMS = MEMPRAGE_RMS or tfl_mgh_multiecho_3D_1mm_iso_MGHprotocol_RMS
%anat1 or anat = MPRAGE
%rest1 = ep2d_FMRI_resting_1 or fMRI_Resting_1 or fMRI_resting_state or ep2d_FMRI_resting or ep2d_FMRI_resting\ 
%rest2 = ep2d_FMRI_resting_2 or fMRI_Resting_2


path_raw = [root_path 'svip_database_all/'];
list_subject = dir(path_raw);
list_subject = {list_subject.name};
list_subject = list_subject(~ismember(list_subject,{'.','..'}));


for num_s = 1:length(list_subject)
    subject = list_subject{num_s};

    %tmp_name_parse = textscan(subject,'%s','delimiter','.');
    %subject_no_dot = [tmp_name_parse{}{}];

    tmp_path_subj = [path_raw subject filesep];
    files_in.(subject).anat = [];
    files_in.(subject).fmri = [];
    %files_in.(subject.fmri.rest2 = [];
    
    try
        files_in.(subject).fmri.rest1 = [tmp_path_subj dir([tmp_path_subj '*_rest1/*.nii.gz'])(1).name];
    catch exception
    warning ('The file %s does not exist, I suppressed that file from the pipeline %s','rest1',subject);
    end

    try
        files_in.(subject).fmri.rest2 = [tmp_path_subj dir([tmp_path_subj '*_rest2/*.nii.gz'])(1).name];
    catch exception
    warning ('The file %s does not exist, I suppressed that file from the pipeline %s','rest2',subject);
    end

    try
        files_in.(subject).anat = [tmp_path_subj dir([tmp_path_subj '*_anat_RMS/*.nii.gz'])(1).name];
    catch exception
        warning ('The file %s does not exist, I suppressed that subject %s','RMS',subject);
        files_in = rmfield(files_in,subject);
    end
end


%% Pipeline options  %%
%% General
opt.folder_out   = '/gs/project/gsf-624-aa/simons_vip/svip_testout_2016_10_06';      
opt.size_output = 'quality_control';                              

%% Pipeline manager 

%% Slice timing correction (niak_brick_slice_timing)
opt.slice_timing.type_acquisition = 'interleaved ascending'; % Slice timing order (available options : 'sequential ascending', 'sequential descending', 'interleaved ascending', 'interleaved descending')
opt.slice_timing.type_scanner     = 'Siemens';                % Scanner manufacturer. Only the value 'Siemens' will actually have an impact
opt.slice_timing.delay_in_tr      = 0;                       % The delay in TR ("blank" time between two volumes)
opt.slice_timing.suppress_vol     = 4;                       % Number of dummy scans to suppress.
opt.slice_timing.flag_nu_correct  = 1;                       % Apply a correction for non-uniformities on the EPI volumes (1: on, 0: of). This is particularly important for 32-channels coil.
opt.slice_timing.arg_nu_correct   = '-distance 200';         % The distance between control points for non-uniformity correction (in mm, lower values can capture faster varying slow spatial drifts).
opt.slice_timing.flag_center      = 1;                       % Set the origin of the volume at the center of mass of a brain mask. This is useful only if the voxel-to-world transformation from the DICOM header has somehow been damaged. This needs to be assessed on the raw images.
opt.slice_timing.flag_skip        = true;                    % Skip the slice timing (0: don't skip, 1 : skip). Note that only the slice timing corretion portion is skipped, not all other effects such as FLAG_CENTER or FLAG_NU_CORRECT
 
% resampling in stereotaxic space
opt.resample_vol.interpolation = 'trilinear'; % The resampling scheme. The fastest and most robust method is trilinear. 
opt.resample_vol.voxel_size    = [3 3 3];     % The voxel size to use in the stereotaxic space
opt.resample_vol.flag_skip     = 0;           % Skip resampling (data will stay in native functional space after slice timing/motion correction) (0: don't skip, 1 : skip)

% Linear and non-linear fit of the anatomical image in the stereotaxic
% space (niak_brick_t1_preprocess)
opt.t1_preprocess.nu_correct.arg = '-distance 75'; % Parameter for non-uniformity correction. 200 is a suggested value for 1.5T images, 75 for 3T images. If you find that this stage did not work well, this parameter is usually critical to improve the results.
opt.t1_preprocess.crop_neck = 0.2 % To crop (20%)

% Temporal filtering (niak_brick_time_filter)
opt.time_filter.hp = 0.01; % Cut-off frequency for high-pass filtering, or removal of low frequencies (in Hz). A cut-off of -Inf will result in no high-pass filtering.
opt.time_filter.lp = Inf;  % Cut-off frequency for low-pass filtering, or removal of high frequencies (in Hz). A cut-off of Inf will result in no low-pass filtering.

% Regression of confounds and scrubbing (niak_brick_regress_confounds)
opt.regress_confounds.flag_wm = true;            % Turn on/off the regression of the average white matter signal (true: apply / false : don't apply)
opt.regress_confounds.flag_vent = true;          % Turn on/off the regression of the average of the ventricles (true: apply / false : don't apply)
opt.regress_confounds.flag_motion_params = true; % Turn on/off the regression of the motion parameters (true: apply / false : don't apply)
opt.regress_confounds.flag_gsc = false;          % Turn on/off the regression of the PCA-based estimation of the global signal (true: apply / false : don't apply)
opt.regress_confounds.flag_scrubbing = true;     % Turn on/off the scrubbing of time frames with excessive motion (true: apply / false : don't apply)
opt.regress_confounds.thre_fd = 0.5;             % The threshold on frame displacement that is used to determine frames with excessive motion in the scrubbing procedure

% Correction of physiological noise (niak_pipeline_corsica)
opt.corsica.sica.nb_comp             = 60;    % Number of components estimated during the ICA. 20 is a minimal number, 60 was used in the validation of CORSICA.
opt.corsica.threshold                = 0.15;  % This threshold has been calibrated on a validation database as providing good sensitivity with excellent specificity.
opt.corsica.flag_skip                = 1;     % Skip CORSICA (0: don't skip, 1 : skip). Even if it is skipped, ICA results will be generated for quality-control purposes. The method is not currently considered to be stable enough for production unless it is manually supervised.

% Spatial smoothing (niak_brick_smooth_vol)
opt.smooth_vol.fwhm      = 6;  % Full-width at maximum (FWHM) of the Gaussian blurring kernel, in mm.
opt.smooth_vol.flag_skip = 0;  % Skip spatial smoothing (0: don't skip, 1 : skip)


[pipeline,opt] = niak_pipeline_fmri_preprocess(files_in,opt);
