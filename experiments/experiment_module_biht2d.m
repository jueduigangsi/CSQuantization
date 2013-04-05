function [XF results] = experiment_module_biht2d(X,target_bitrate,params)
% function results = experiment_module_biht2d
%
% CSQ Experimental Module for BIHT-2D. For more information regarding the
% CSQ Experimental Module format, please refer to the CSQEM documentation.

%% Setup
csq_required_parameters(params,'htol','maxIter','threshold',...
                           'block_based','projection',...
                           'xform');

% Assume X is coming in as an image matrix
params.imsize = size(X);
params.N = length(X(:));
% Set wavelet decomposition levels
if ~isfield(params,'L')
    params.L = log2(min(params.imsize))-1;     % Wavelet decomposition levels
end
params.smoothing = @(z) z;

% Some input checking for different experiment modes
if params.block_based
    csq_required_parameters(params,'block_dim','smooth_id');
    
    % Get smoothing function
    params.smoothing = csq_generate_smoothing(params.smooth_id,params);
end

switch params.threshold
    case 'bivariate-shrinkage'
        csq_required_parameters(params,'lambda');
        params.end_level = params.L - 1;
        params.windowsize = 3;
    case 'top'
        csq_required_parameters(params,'k');
end

switch params.projection
    case 'srm-blk'
        csq_required_parameters(params,'blksize','trans_mode');
end

% Determine subrate from bitrate
%   For the BIHT, since all measurements are 1 bit, the target bitrate (in
%   bpp) uniquely determines the subrate we should use. 
params.subrate = target_bitrate;
params.M = round(params.subrate*params.N); % Get number of measurements

% Generate projection set
[Phi Phi_t] = csq_generate_projection(params.projection,params);

% Generate transform set
[Psi Psi_t] = csq_generate_xform(params.xform,params);

% Unification
[A AT] = csq_unify_projection(Phi,Phi_t,Psi,Psi_t);

% Generate threshold
params.threshold = csq_generate_threshold(params.threshold,params);

% BIHT Recovery parameters
params.ATrans = AT;
params.invpsi = Psi_t;
params.psi = Psi;

%% Experiment
% Normalization and mean subtraction
Xeng = norm(X(:));
xn = X(:) ./ Xeng;
xmean = mean(xn);
xn = xn - xmean;

% Projection
y = sign(Phi(xn));

% Recovery
tic 
    [XF iterations] = biht_1d(y,A,params);
results.run_time = toc;

% Adding the mean back
XF = XF + xmean;

% Returning the energy
XF = XF .* Xeng;

% Reshape
XF = reshape(XF,params.imsize);

%% Finishing
% Outputs
results.iterations = iterations;
results.params = params;
results.Phi = Phi;
results.Phi_t = Phi_t;
results.Psi = Psi;
results.Psi_t = Psi_t;
results.true_bitrate = length(y) ./ params.N;
results.target_bitrate = target_bitrate;


