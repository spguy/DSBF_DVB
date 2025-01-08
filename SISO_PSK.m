% "Choose a Propagation Model" describes how to choose proper propagation models
% "Fading Channels" explains Rayleigh and Racian Fading Channels
% "phased.LOSchannel" gives an example of establishing a link with radiator
%% initialization 
% PSK modulation + raised cosine transmit filter
clc
clear
close all
c = physconst('Lightspeed');
% parameters
M = 8;% PSK阶数
dataRate = 200e6;
dataLength = 1000;
seed = 7; % 设置一个固定的种子
rng(seed);
fop = 14.7e9;%RF wave operating frequency
lambda = c/fop;
data = randi([0 M-1], 1000, 1); % 随机生成数据包
Signal = pskmod(data,M);%M-PSK modulation 

% initialize a raised cosine filter
Nsym = 6;           % Filter span in symbol durations
beta = 0.5;         % Roll-off factor
sampsPerSym = 8;    % Upsampling factor
fs = sampsPerSym*dataRate;%sample frequency
sampleLength = sampsPerSym * dataLength;
rctFilt = comm.RaisedCosineTransmitFilter(...
  'Shape','Square root', ...
  'RolloffFactor',beta, ...
  'FilterSpanInSymbols',Nsym, ...
  'OutputSamplesPerSymbol',sampsPerSym);
% Normalize to obtain maximum filter tap value of 1
b = coeffs(rctFilt);
rctFilt.Gain = 1/max(b.Numerator);
tx = 1000*(0:dataLength-1)/dataRate;% Time vector sampled at symbol rate in milliseconds

snrPoints = 1;
disPoints = 1;
snrStep = 200;
disStep = 1000;
errRateRec = zeros(snrPoints,disPoints);
receivePowerGainRec = zeros(snrPoints,disPoints);
EVMRec = zeros(snrPoints,disPoints);
for i = 1:snrPoints
    for j = 1:disPoints
        snr = i * snrStep;
        dis = j * disStep;
RCTSignal = rctFilt([Signal;zeros(Nsym/2,1)]);% generate mid-frequency signal
% spectrumAnalyzer = spectrumAnalyzer(SampleRate=2e6);
% spectrumAnalyzer(data)
% release(spectrumAnalyzer)
% the bandwidth can be calculated as B=R(1+β) where R is the 
% data rate and beta is the roll-off factor
%%
%compensating the filter delay
fltDelay = Nsym / (2*dataRate);
RCTSignal = RCTSignal(fltDelay*fs+1:end);
%% free space/LOS propagation

pos1 = [dis;dis;dis];
pos2 = [0;0;0];
vel1 = [0;0;0];
vel2 = [0;0;0];
R = sqrt((pos1-pos2)'*(pos1-pos2));
L = (4*pi*R/lambda)^2;
delaySymbol = round(fs*R/c);%time delay due to propagation, count as symbols
axes = eye(3,3);
[radiatingRng,radiatingAngles] = rangeangle(pos2,pos1,axes);
%freespace object
freesp = phased.FreeSpace(SampleRate=fs,OperatingFrequency=fop);
%antenna element object(circular polarized)
antennaTx = phased.CrossedDipoleAntennaElement( ...
    'Polarization','RHCP');
%pattern(antennaTx,fop,-180:180,-90:90,'CoordinateSystem','polar', 'Type','powerdb','Polarization','Combined');
%array object, defined as URA
arrayTx = phased.URA( ...
    'Element', antennaTx, ...
    'Size',[8 8], ...
    'ElementSpacing',0.5*lambda, ...
    'ArrayNormal','z');
%the arraynormal means array locate parallel to xy plane, point natrually at the z axis
%BF weights
steervecTx = phased.SteeringVector('SensorArray',arrayTx);
%calculating BF weights(only steering to target angle)
BFweightsTx = steervecTx(fop,radiatingAngles);

%pattern(arrayTx,fop,-180:180,-90:90,'CoordinateSystem','polar','PropagationSpeed',c,'Type','powerdb','Weights',BFweightsTx)
%radiation object
radiator = phased.Radiator( ...
    'Sensor',arrayTx, ...
    'PropagationSpeed',c, ...
    'OperatingFrequency',fop, ...
    'Polarization','Combined', ...
    'WeightsInputPort',true);

%signal radiation
FreOffset = 150e3;
RCTSignal = frequencyOffset(RCTSignal,fs,FreOffset);
RCTSignal = [RCTSignal;zeros(delaySymbol,1)];%To ensure that signal is long enough
radiatSignal = radiator(RCTSignal,radiatingAngles,axes,BFweightsTx);
propagatedSignal = freesp(radiatSignal,pos1,pos2,vel1,vel2);
%%
%plot(1:1000,RCTSignal(1:1000),1:1000,sqrt(RCTSignal'*RCTSignal)*receiveSignal(1:1000)*exp(1i*2*pi*R/lambda)/sqrt(receiveSignal'*receiveSignal))
%% signal receive
[receiveRng,receiveAngles] = rangeangle(pos1,pos2,axes);
antennaRx = phased.CrossedDipoleAntennaElement('Polarization','RHCP');
%% use an array for receive
%arrayRx = phased.URA('Element',antennaRx,'Size',[8 8],'ElementSpacing',0.5*lambda,'ArrayNormal','z');
%BF weights Rx
%steervecTx = phased.SteeringVector('SensorArray',arrayRx);
%calculating BF weights(only steering to target angle)
%BFweightsRx = steervecTx(fop,receiveAngles);

collector = phased.Collector( ...
    'Sensor',antennaRx, ...
    'PropagationSpeed',c, ...
    'OperatingFrequency',fop, ...
    'Polarization','Combined', ...
    'WeightsInputPort',false);
receiveSignal = collector(propagatedSignal,receiveAngles,axes);
figure
%receiveSignal = sum(receiveSignal,2);%for BF summation

%fprintf('Propagation loss = %fdB\n',-10*log10(L));
receiveSignal = [receiveSignal(delaySymbol+1:end)];%The first several symbols are zero(not arrive yet)
receivePower = 10*log10(receiveSignal'*receiveSignal/length(receiveSignal));
baseSignal = awgn(RCTSignal(1:sampleLength),snr);
basePower = 10*log10(baseSignal'*baseSignal/length(baseSignal));
receivePowerGainRec(i,j) = receivePower-basePower;

% add AWGN noise(only add ampliude noise)
noisySignal = awgn(receiveSignal,snr);
%noisySignal = awgn(RCTSignal(1:(end-delaySymbol-1)),snr);%有线传输情况
%% PSK demodulation + raised cosine receive filter
rcrFilt = comm.RaisedCosineReceiveFilter(...
  'Shape','Square root', ...
  'RolloffFactor',beta, ...
  'FilterSpanInSymbols',Nsym, ...
  'InputSamplesPerSymbol',sampsPerSym);
b1 = coeffs(rcrFilt);
rcrFilt.Gain = 1/sum(b1.Numerator);
RCRSignal = rcrFilt([noisySignal;zeros(Nsym*sampsPerSym/2,1)]);
RCRSignal = RCRSignal(fltDelay*fs/rcrFilt.DecimationFactor+1:end);

%% signal correction（only phase correction is required）
% phase correction is conducted at frame level, the phase compensations for
% symbols within one flame are the same
frameLength = 10;
phaseCompensateFrame = zeros(dataLength,1);
for q = 1:dataLength/frameLength
    for p = 1:frameLength
phaseCompensateFrame(frameLength*(q-1)+p,1) =  angle(Signal(frameLength*(q-1)+1)./RCRSignal(frameLength*(q-1)+1));
    end
end
phaseCompensatePath = wrapToPi(2*pi*R/lambda);
correctSignal = RCRSignal.*exp(1j*phaseCompensateFrame);


%% constellation comparison 
NM = Signal'*Signal/(correctSignal'*correctSignal);
constDiag = comm.ConstellationDiagram(2, ...
    'ShowReferenceConstellation',false, ...
    'ShowLegend',true, ...
    'ChannelNames', ...
    {'originalSignal','correctSignal'});
constDiag(Signal,correctSignal*sqrt(NM));
evm = comm.EVM(  'MaximumEVMOutputPort',true, ...
    'XPercentileEVMOutputPort',true, ...
    'SymbolCountOutputPort',true);
%the highest value of the Error Vector Magnitude (EVM)

%For example, if you set the XPercentileValue to 95, 
%then 95% of all EVM measurements since the last reset 
%fall below the value of xEVM. 

%number of symbols used to measure the X-percentile EVM
NM = Signal'*Signal/(RCRSignal'*RCRSignal);
[rmsEVM1,maxEVM,xEVM,numSys] = evm(Signal,correctSignal*sqrt(NM));
fprintf('EVM=%f\n',rmsEVM1);
EVMRec(i,j) = rmsEVM1;
%% receive M-PSK demodulation
dataOut = pskdemod(correctSignal,M);
[errNum,errRate,errInd] = symerr(data,dataOut);
fprintf('SNR = %d\ntotalBits = %f\nerrorBits = %d\nerrorRate = %d',snr,length(data),errNum,errRate);
errRateRec(i,j) = errRate;
    end
end
%%
[X,Y] = meshgrid(1:snrStep:snrPoints*snrStep,1:disStep:disStep*disPoints);

figure
surf(X,Y,20*log10(EVMRec/100).')
xlabel('-Noise Level(dBW)')
ylabel('Distance(m)')
zlabel('EVM(dB)')
title('EVM')
figure
surf(X,Y,errRateRec.') 
xlabel('-Noise Level(dBW)')
ylabel('Distance(m)')
zlabel('Error Rate(%)')
title('误码率')
figure
surf(X,Y,receivePowerGainRec.')
xlabel('-Noise Level(dBW)')
ylabel('Distance(m)')
zlabel('PowerGain(dB)')
title('ReceivingPowerGain')

%由于AWGN只引入幅度误差，在PSK解调时不会收到AWGN水平的影响，而只与相位误差有关
