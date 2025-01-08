% "Choose a Propagation Model" describes how to choose proper propagation models
% "Fading Channels" explains Rayleigh and Racian Fading Channels
%% QAM调制
clc
clear
close all
N = 2;%发射源数量
M = 8;%调制阶数
dataLength = 1000;
data = randi([0 M-1], dataLength, 1); % 随机生成数据包
Signal = pskmod(data,M);
figure
plot(real(Signal));
title('QAM调制信号');
%% free space propagation(LOS)
fs = 8e3;
fc = 3e8;
freesp = phased.FreeSpace(SampleRate=fs,OperatingFrequency=fc);
x = Signal;
%x y z coordinates of locations
%x y z of velocities
posTx = [1 -1;0 0;200 200];
posRx = [0 0;0 0;0 0];
velTx = [0 0;0 0;0 0];
velRx = [0 0;0 0;0 0];
propagatedSignal = zeros(dataLength,N);
for i = 1:N
propagatedSignal(:,i) = freesp(x,posTx(:,i),posRx(:,i),velTx(:,i),velRx(:,i));
end

%%
R = sqrt((posTx-posRx)'*(posTx-posRx));
lambda = physconst('Lightspeed')/fc;
L = (4*pi*R/lambda).^2;
% 计算传播引起的相移`
thetaProp = 2 * pi * diag(R) / lambda;
thetaProp = wrapToPi(thetaProp);
%%
figure
a = 1:200;
aa = propagatedSignal(:,1)'*propagatedSignal(:,1)/length(propagatedSignal);
plot(a,propagatedSignal(a,1)/sqrt(aa),a,x(a,1).*exp(-1j * thetaProp(1)))
%% signal summation and correction
%通过计算接收信号和参考信号之间的相位差来补偿
theta = mean(angle(propagatedSignal./Signal));
theta = theta + [0,0.2*pi];
phaseCorrectSignal = propagatedSignal.* exp(-1j * 0 * theta);

CorrectSignal = phaseCorrectSignal;%不进行幅度调整不会影响误码率
figure;
plot(angle(CorrectSignal(1:24,1)));
title('第一路');
figure;
plot(angle(CorrectSignal(1:24,2)));
title('第二路');
%signal summation
SumSignal = sum(CorrectSignal,2);%按列相加
figure;
plot(angle(SumSignal(1:24)));
title('合路');
P = SumSignal'*SumSignal/length(SumSignal);
snr = 150;
noisySignal = awgn(SumSignal,snr,'measured');
%先合成再加噪 参考Distributed Transmit Beamforming: 
%Design andDemonstration From the Lab to UAVs

%% constellation comparison of pre and AWGN
constDiag = comm.ConstellationDiagram(3, ...
    'ShowReferenceConstellation',true, ...
    'ShowLegend',true, ...
    'XLimits',[-2 2],'YLimits',[-2 2], ...
    'ChannelNames', ...
    {'SumSignal','First','Second'});
constDiag(zscore(noisySignal), ...
    1.1*zscore(CorrectSignal(:,1)), ...
    1.2*zscore(CorrectSignal(:,2)));
% 绘制加噪信号
figure;
plot(real(noisySignal));
title('校正后的合成信号');

%% receive QPSK demodulation
dataOut = pskdemod(noisySignal,M);
[errNum,errRate,errInd] = symerr(data,dataOut);
fprintf('totalBits = %f\nerrorBits = %d\nerrorRate = %d',dataLength,errNum,errRate);