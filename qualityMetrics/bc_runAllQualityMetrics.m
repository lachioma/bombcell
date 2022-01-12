function [qMetric, goodUnits] = bc_runAllQualityMetrics(param, spikeTimes, spikeTemplates, ...
    templateWaveforms, templateAmplitudes, pcFeatures, pcFeatureIdx)
% JF
% ------
% Inputs
% ------
% param: parameter structure with fields:
%   tauR = 0.0010; %refractory period time (s)
%   tauC = 0.0002; %censored period time (s)
%   maxPercSpikesMissing: maximum percent (eg 30) of estimated spikes below detection 
%       threshold to define timechunks in the recording on which to compute
%       quality metrics for each unit. 
%   minNumSpikes: minimum number of spikes (eg 300) for unit to classify it as good 
%   maxNtroughsPeaks: maximum number of troughs and peaks (eg 3) to classify unit
%       waveform as good
%   axonal: boolean, whether to keep or not axonal spikes
%   maxRPVviolations: maximum estimated fraction (eg 0.2) of refractory period violations to classify unit as good
%   minAmplitude: minimum amplitude of raw waveform in microVolts to
%       classify unit as good
%   plotThis: boolean, whether to plot figures for each metric and unit
%   rawFolder: string containing the location of the raw .dat or .bin file 
%   deltaTimeChunk: size of time chunks to cut the recording in, in seconds
%       (eg 600 for 10 min time chunks)
%   ephys_sample_rate: recording sample rate (eg 30000)
%   nChannels: number of recorded channels, including any sync channels (eg
%       385)
%   nRawSpikesToExtract: number of spikes to extract from the raw data for
%       each waveform (eg 100)
%   nChannelsIsoDist: number of channels on which to compute the distance
%       metrics (eg 4)
% spikeTimes: nSpikes × 1 uint64 vector giving each spike time in samples (*not* seconds)
% spikeTemplates: nSpikes × 1 uint32 vector giving the identity of each
%   spike's matched template
% templateWaveforms: nTemplates × nTimePoints × nChannels single matrix of
%   template waveforms for each template and channel
% templateAmplitudes: nSpikes × 1 double vector of the amplitude scaling factor
%   that was applied to the template when extracting that spike
% pcFeatures: nSpikes × nFeaturesPerChannel × nPCFeatures  single 
%   matrix giving the PC values for each spike.
% pcFeatureIdx: nTemplates × nPCFeatures uint32  matrix specifying which 
%   channels contribute to each entry in dim 3 of the pc_features matrix
% ------
% Outputs
% ------
% qMetric: structure with fields:
%   percSpikesMissing
%   useTheseTimes
%   nSpikes
%   nPeaks
%   nTroughs
%   axonal
%   Fp
%   rawAmplitude
%   spatialDecay
%   isoD
%   Lratio
%   silhouetteScore
% goodUnits: boolean nUnits x 1 vector indicating whether each unit met the
%   threshold criterion to be classified as good

%% prepare for quality metrics computations: get waveform max_channel and raw waveforms

maxChannels = bc_getWaveformMaxChannel(templateWaveforms);

rawWaveforms = bc_extractRawWaveformsFast(param.rawFolder, param.nChannels, param.nRawSpikesToExtract, spikeTimes, spikeTemplates, param.rawFolder, 1); % takes ~10'

%% loop through units and get quality metrics
qMetric = struct;
uniqueTemplates = unique(spikeTemplates);
spikeTimes = spikeTimes ./ param.ephys_sample_rate; %convert to seconds after using sample indices to extract raw waveforms
timeChunks = min(spikeTimes):param.deltaTimeChunk:max(spikeTimes);

for iUnit = 1:length(uniqueTemplates)
    clearvars thisUnit theseSpikeTimes theseAmplis

    thisUnit = uniqueTemplates(iUnit);
    theseSpikeTimes = spikeTimes(spikeTemplates == thisUnit);
    theseAmplis = templateAmplitudes(spikeTemplates == thisUnit);

    %% percentage spikes missing
    percSpikesMissing = bc_percSpikesMissing(theseAmplis, theseSpikeTimes, timeChunks, param.plotThis);

    %% define timechunks to keep
    [qMetric.percSpikesMissing(iUnit), theseSpikeTimes, theseAmplis, timeChunks, qMetric.useTheseTimes{iUnit}] = bc_defineTimechunksToKeep(percSpikesMissing, ...
        param.maxPercSpikesMissing, theseAmplis, theseSpikeTimes, timeChunks);

    %% number spikes
    qMetric.nSpikes(iUnit) = bc_numberSpikes(theseSpikeTimes);

    %% waveform: number peaks/troughs and is peak before trough (= axonal)
    [qMetric.nPeaks(iUnit), qMetric.nTroughs(iUnit), qMetric.axonal(iUnit)] = bc_troughsPeaks(templateWaveforms(thisUnit, :, maxChannels(iUnit)), ...
        param.ephys_sample_rate, param.plotThis);

    %% fraction contam (false postives)
    [qMetric.Fp(iUnit), ~, ~] = bc_fractionRPviolations(numel(theseSpikeTimes), theseSpikeTimes, param.tauR, param.tauC, ...
        timeChunks(end)-timeChunks(1), param.plotThis);

    %% amplitude
    qMetric.rawAmplitude(iUnit) = bc_getRawAmplitude(rawWaveforms(thisUnit).spkMapMean(rawWaveforms(thisUnit).peakChan, :), ...
        param.rawFolder);

    %% distance metrics
    [qMetric.isoD(iUnit), qMetric.Lratio(iUnit), qMetric.silhouetteScore(iUnit)] = bc_getDistanceMetrics(pcFeatures, ...
        pcFeatureIdx, thisUnit, qMetric.nSpikes(iUnit), spikeTemplates == thisUnit, spikeTemplates, param.nChannelsIsoDist, param.plotThis);

end
goodUnits = qMetric.nSpikes > 300; 
end