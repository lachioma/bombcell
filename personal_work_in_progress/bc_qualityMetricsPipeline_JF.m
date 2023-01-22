%% load data 
animals = {'JF089'};
bhvProtocol = '';

animal = animals{1};
experiments = AP_find_experimentsJF(animal, bhvProtocol, true);
experiments = experiments([experiments.ephys]);

day = experiments(1).day;
experiment = experiments(1).experiment;
site = 1;

ephysPath = AP_cortexlab_filenameJF(animal,day,experiment,'ephys',site);
[spikeTimes, spikeTemplates, ...
    templateWaveforms, templateAmplitudes, pcFeatures, pcFeatureIdx, usedChannels] = bc_loadEphysData(ephysPath);
ephysap_path = AP_cortexlab_filenameJF(animal,day,experiment,'ephys_ap',site);
%ephysMetaDir = dir([ephysap_path, '/../../../structure.oebin']);
ephysMetaDir = dir([ephysap_path, '/../*ap.meta']);
ephysDirPath = AP_cortexlab_filenameJF(animal,day,experiment,'ephys_dir',site);
savePath = fullfile(ephysDirPath, 'qMetrics'); 

%% run qmetrics 
param = bc_qualityParamValues(ephysMetaDir, ephysap_path); 


%% compute quality metrics 
ephysDirPath = AP_cortexlab_filenameJF(animal, day, experiment, 'ephys_dir',site);
savePath = fullfile(ephysDirPath, 'qMetrics');
qMetricsExist = dir(fullfile(savePath, 'qMetric*.mat'));

if isempty(qMetricsExist) || rerun
    [qMetric, unitType] = bc_runAllQualityMetrics(param, spikeTimes, spikeTemplates, ...
        templateWaveforms, templateAmplitudes,pcFeatures,pcFeatureIdx,usedChannels, savePath);
else
    load(fullfile(savePath, 'qMetric.mat'))
    load(fullfile(savePath, 'param.mat'))
    unitType = nan(length(qMetric.percSpikesMissing),1);
    unitType(qMetric.nPeaks > param.maxNPeaks | qMetric.nTroughs > param.maxNTroughs |qMetric.axonal == param.axonal) = 0; %NOISE OR AXONAL
    unitType(qMetric.percSpikesMissing <= param.maxPercSpikesMissing & qMetric.nSpikes > param.minNumSpikes & ...
        qMetric.nPeaks <= param.maxNPeaks & qMetric.nTroughs <= param.maxNTroughs & qMetric.Fp <= param.maxRPVviolations & ...
        qMetric.axonal == param.axonal & qMetric.rawAmplitude > param.minAmplitude) = 1;%SINGLE SEXY UNIT
    unitType(isnan(unitType)) = 2;% MULTI UNIT 
end
%% unit quality GUI 

% put ephys data into structure 
ephysData = struct;
ephysData.spike_times = spikeTimes;
ephysData.spike_times_timeline = spikeTimes ./ 30000;
ephysData.spike_templates = spikeTemplates;
ephysData.templates = templateWaveforms;
ephysData.template_amplitudes = templateAmplitudes;
ephysData.channel_positions = readNPY([ephysPath filesep 'channel_positions.npy']);
ephysData.ephys_sample_rate = 30000;
ephysData.waveform_t = 1e3*((0:size(templateWaveforms, 2) - 1) / 30000);
ephysParams = struct;
plotRaw = 1;
probeLocation=[];
unitQualityGUI(ap_data.data.data,ephysData,qMetric, param, probeLocation, unitType, plotRaw);
