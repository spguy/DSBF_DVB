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
N = 2;%发射源数量
dataRate = 200e6;
dataLength = 10000;
seed = 7; % 设置一个固定的种子
rng(seed);
fop = 13.7e9;%RF wave operating frequency
lambda = c/fop;
data = randi([0 M-1], dataLength, 1); % 随机生成数据包
Signal = pskmod(data,M);%M-PSK modulation 

% initialize a raised cosine filter
Nsym = 6;           % Filter span in symbol durations
beta = 0.5;         % Roll-off factor
sampsPerSym = 8;    % Upsampling factor
sampleLength = sampsPerSym * dataLength;
fs = sampsPerSym*dataRate;%sample frequency
rctFilt = comm.RaisedCosineTransmitFilter(...
  'Shape','Normal', ...
  'RolloffFactor',beta, ...
  'FilterSpanInSymbols',Nsym, ...
  'OutputSamplesPerSymbol',sampsPerSym);

% Normalize to obtain maximum filter tap value of 1
b = coeffs(rctFilt);
rctFilt.Gain = 1/max(b.Numerator);
tx = 1000 * (0:dataLength-1)/dataRate;% Time vector sampled at symbol rate in milliseconds
to = 1000 * (0: (dataLength)*sampsPerSym - 1) / fs;
snr_dbwPoints = 1;
disPoints = 1;
snr_dbwStep = 150;
disStep = 1;
errRateRec = zeros(snr_dbwPoints,disPoints);
receivePowerGainRec = zeros(snr_dbwPoints,disPoints);
EVMRec = zeros(snr_dbwPoints,disPoints);
SNRRec = zeros(snr_dbwPoints,disPoints);
for i = 1:snr_dbwPoints
    for j = 1:disPoints
        snr_dbw = i * snr_dbwStep;
        dis = (j* disStep)*2;
RCTSignal = rctFilt([Signal;zeros(Nsym/2,1)]);% generate mid-frequency signal

%compensating the filter delay
fltDelay = Nsym / (2*dataRate);
RCTSignal = RCTSignal(fltDelay*fs+1:end);
%% 全段注释掉即可
%%%%%%%%%%%%%%%%%%%%% 有线传输模拟，发送滤波后直接接收滤波%%%%%%%%%%%%%%%%%
% rcrFilt = comm.RaisedCosineReceiveFilter(...
%   'Shape','Normal', ...
%   'RolloffFactor',beta, ...
%   'FilterSpanInSymbols',Nsym, ...
%   'InputSamplesPerSymbol',sampsPerSym, ...
%   'DecimationFactor',sampsPerSym);
% b1 = coeffs(rcrFilt);
% rcrFilt.Gain = 1/sum(b1.Numerator);
% RCRSignal = rcrFilt([RCTSignal;zeros(Nsym*sampsPerSym/2,1)]);
% RCRSignal = RCRSignal(fltDelay*fs/rcrFilt.DecimationFactor+1:end);
% a = 1:100;
% figure
% plot(a,(Signal(a,1)),a,(RCRSignal(a,1)))
% title('re')
% constDiag = comm.ConstellationDiagram(2, ...
%     'ShowReferenceConstellation',false, ...
%     'ShowLegend',true, ...
%     'ChannelNames', ...
%     {'originalSignal','RCRSignal'});
% constDiag(Signal,RCRSignal);


%% free space/LOS propagation
posTx = [1 -1;-1 -1;0 0];
%y轴作为基准轴，阵面垂直于y，
posRx = [0 0;0 0;0 0];
velTx = [0 0;0 0;0 0];
velRx = [0 0;0 0;0 0];
axes = eye(3,3);
R = sqrt((posTx-posRx)'*(posTx-posRx));
L = (4*pi*R/lambda)^2;%path loss
delaySymbol = zeros(N,1);
for ii =1:N
delaySymbol(ii) = round(fs*R(ii,ii)/c);%time delay due to propagation, count as symbols
end
delaySymbol = max(delaySymbol);
radiatingAngles = zeros(2,N);%elevating angle and azimuth angle
for ii = 1:N
[a,radiatingAngles(:,ii)] = rangeangle(posRx(:,ii),posTx(:,ii),axes);
end
%freespace object
freesp = phased.FreeSpace(SampleRate=fs,OperatingFrequency=fop);
%antenna element object(circular polarized)
antennaTx = phased.CrossedDipoleAntennaElement( ...
    'Polarization','RHCP');
pattern(antennaTx,fop,-180:180,-90:90,'CoordinateSystem','polar', ...
    'Type','powerdb','Polarization','Combined');
title('element 3d')
%array object, defined as URA
arrayLength = 8;
arrayWidth = 8;
elementNum = arrayLength * arrayWidth;
arrayTx = phased.URA( ...
    'Element', antennaTx, ...
    'Size',[8 8], ...
    'ElementSpacing',0.5*lambda, ...
    'ArrayNormal','y');
%the arraynormal means array locate parallel to xy plane, point natrually at the z axis
%BF weights
steervecTx = phased.SteeringVector('SensorArray',arrayTx);
%calculating BF weights(only steering to target angle)
BFweightsTx = zeros(elementNum,N);
for ii = 1:N
BFweightsTx(:,ii) = steervecTx(fop,(radiatingAngles(:,ii)));
end

%radiation object
radiator = phased.Radiator( ...  
    'Sensor',arrayTx, ...
    'PropagationSpeed',c, ...
    'OperatingFrequency',fop, ...
    'Polarization','Combined', ...   
    'WeightsInputPort',true);
%signal radiation
FreOffset = 0;
RCTSignal = frequencyOffset(RCTSignal,fs,FreOffset);
RCTSignal = [RCTSignal;zeros(delaySymbol,1)];%To ensure that signal is long enough
%% directional figure or each Tx array
% figure
% subplot(1,2,1)
% pattern(arrayTx,fop,-180:180,0:90,'CoordinateSystem','polar', ...
%     'PropagationSpeed',c,'Type','powerdb','Weights',BFweightsTx(:,1))
% subplot(1,2,2)
% pattern(arrayTx,fop,-180:180,0:90,'CoordinateSystem','polar', ...
%     'PropagationSpeed',c,'Type','powerdb','Weights',BFweightsTx(:,2))
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
carrier = 0:2*pi*fop/fs:(length(RCTSignal)-1)*2*pi*fop/fs;
carrierSignal = 10*exp(1j.*carrier).';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for ii =1:N
radiatSignal(ii) = radiator(RCTSignal,radiatingAngles(:,ii),axes,BFweightsTx(:,ii));
propagatedSignal(ii) = freesp(radiatSignal(ii),posTx(:,ii),posRx(:,ii),velTx(:,ii),velRx(:,ii));
end
%% signal receive
receiveAngles = zeros(2,N);
for ii = 1:N
    [b,receiveAngles(:,ii)] = rangeangle(posTx(:,ii),posRx(:,ii),axes);
end
antennaRx = phased.CrossedDipoleAntennaElement('Polarization','RHCP');

%% use an array for receive
collector = phased.Collector( ...
    'Sensor',antennaRx, ...
    'PropagationSpeed',c, ...
    'OperatingFrequency',fop, ...
    'Polarization','Combined', ...
    'WeightsInputPort',false);
receiveSignal = zeros(sampleLength+delaySymbol,N);
axesR = axes;
axesR(2,2) = -1;%以y轴作为基准
for ii = 1:N
receiveSignal(:,ii) = collector(propagatedSignal(:,ii),receiveAngles(:,ii),axesR);
end
%%
figure
aa = 1:500;
plot(aa,zscore(RCTSignal(aa)),aa,zscore(receiveSignal(aa,1).*exp(1i*2*pi*R(1,1)/lambda)));
%% adding aditional noises (phase and thermal)
receiveSignal = receiveSignal(delaySymbol+1:end,:);
noisSignal = awgn(receiveSignal,snr_dbw);
thNoise = comm.ThermalNoise...
    ('NoiseTemperature',290,'SampleRate',fs);
pnoise = comm.PhaseNoise...
    ('Level',-200,'FrequencyOffset',20);
noisySignal = zeros(sampleLength,N);
for colum =1:N
noisySignal(:,colum) = pnoise(thNoise(noisSignal(:,colum)));
end

%% propagation compensate 1 相位要乘正的
% for ii = 1:N
% noisySignal(:,ii) = noisySignal(:,ii) .*exp(1i*2*pi*R(ii,ii)/lambda);
% end
% 对一路信号施加相位偏移
%noisySignal(:,1) = noisySignal(:,1) .*exp(1i*0.2*pi);
%%
sumSignal = sum(noisySignal,2);

%% 
figure
a = 1:500;
plot(a,(noisySignal(a,1)),a,(noisySignal(a,2)),a,(sumSignal(a)))
title('receive vs.RCT')
legend('re1','re2','sum');
%% PSK demodulation + raised cosine receive filter
rcrFilt = comm.RaisedCosineReceiveFilter(...
  'Shape','Normal', ...
  'RolloffFactor',beta, ...
  'FilterSpanInSymbols',Nsym, ...
  'InputSamplesPerSymbol',sampsPerSym, ...
  'DecimationFactor',sampsPerSym);
b1 = coeffs(rcrFilt);
rcrFilt.Gain = 1/sum(b1.Numerator);
RCRSignal = rcrFilt([sumSignal;zeros(Nsym*sampsPerSym/2,1)]); 
RCRSignal = RCRSignal(fltDelay*fs/rcrFilt.DecimationFactor+1:end);
%% carrierSync
carrierSync = comm.CarrierSynchronizer( ...
    'SamplesPerSymbol',8, ...
    'Modulation','8PSK',...
    'NormalizedLoopBandwidth',0.01);
[RCRSignal1,pherr] = carrierSync(RCRSignal);
%%
receivePower = 10*log10(sumSignal'*sumSignal/length(sumSignal));
%与单个接收信号进行对比，得到分布式波束赋形的功率增益
%baseSignal = noisySignal(:,1);
baseSignal = awgn(RCTSignal(1:sampleLength,1),snr_dbw);
basePower = 10*log10(baseSignal'*baseSignal/length(baseSignal));
receivePowerGainRec(i,j) = receivePower-basePower;
SNRRec(i,j) = receivePower+snr_dbw;
%% phase compensate 2
% frameLength = 10;%controling the accuracy of phase compensation
% phaseCompensateFrame = zeros(dataLength,1);
%     for q = 1:dataLength/frameLength
%         for p = 1:frameLength
%             phaseCompensateFrame(frameLength*(q-1)+p) =  angle(Signal(frameLength*(q-1)+1)./RCRSignal(frameLength*(q-1)+1));
%         end
%     end
% phaseCompensatePath = (wrapToPi(2*pi*R/lambda));
% correctSignal = RCRSignal.*exp(1j*phaseCompensateFrame);

%% constellation comparison 

constDiag = comm.ConstellationDiagram(2, ...
    'ShowReferenceConstellation',false, ...
    'ShowLegend',true, ...
    'ChannelNames', ...
    {'beforCS','afterCS'});
constDiag(zscore(RCRSignal1(1:1000)),zscore(RCRSignal1(9000:9999)));

evm = comm.EVM(  'MaximumEVMOutputPort',true, ...
    'XPercentileEVMOutputPort',true, ...
    'SymbolCountOutputPort',true);
%the highest value of the Error Vector Magnitude (EVM)

%For example, if you set the XPercentileValue to 95, 
%then 95% of all EVM measurements since the last reset 
%fall below the value of xEVM. 

%number of symbols used to measure the X-percentile EVM
[rmsEVM1,maxEVM,xEVM,numSys] = evm(zscore(Signal),zscore(RCRSignal));
fprintf('EVM=%f\n',rmsEVM1);
EVMRec(i,j) = rmsEVM1;
%% receive M-PSK demodulation
dataOut = pskdemod(RCRSignal1,M);
[errNum,errRate,errInd] = symerr(data,dataOut);
fprintf('snr_dbw = %d\nDistance = %f\nerrorRate = %d\n',snr_dbw,R,errRate);
errRateRec(i,j) = errRate;
    end
end

%%
% [X,Y] = meshgrid(snr_dbwStep:snr_dbwStep:snr_dbwPoints*snr_dbwStep,disStep:disStep:disStep*disPoints);
% 
% figure
% surf(X,Y,20*log10(EVMRec/100).')
% xlabel('-Noise Level(dBW)')
% ylabel('Distance(m)')
% zlabel('EVM(dB)')
% title('EVM')
% colorbar
% 
% figure
% surf(X,Y,errRateRec.')
% xlabel('-Noise Level(dBW)')
% ylabel('Distance(m)')
% zlabel('Error Rate(%)')
% title('误码率')
% colorbar
% 
% figure
% surf(X,Y,receivePowerGainRec.')
% xlabel('-Noise Level(dBW)')
% ylabel('Distance(m)')
% zlabel('PowerGain(dB)') 
% title('Distributing Gain')
% colorbar
% 
% figure
% surf(X,Y,SNRRec.')
% xlabel('-Noise Level(dBW)')
% ylabel('Distance(m)')  M
% zlabel('SNR(dB)') 
% title('SNR')
% colorbar
%%
% figure
% plot(disStep:disStep:disStep*disPoints,disStep:disStep:disStep*disPoints,)
% xlabel('Distance(m)')
% ylabel('ErrorRate') 
% legend('N=1','N=2')
% tile('误码率')