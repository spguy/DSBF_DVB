s = serialport("COM3",9600);
%%
orderType = 8;
phase = 0;
amplitude = 0;% 0为最低功率，63为最高功率
channelNum = 0;
angleOffAxis = 70;
angleRotate = 100;
powermode = 0;
i = 0;
    while true
        i = i+1
        serialCom...
        (s,orderType,phase,amplitude,channelNum ...
        ,angleOffAxis,angleRotate,powermode)
        pause(1); % 暂停 1 秒
    end

%%
for channelNum = 0:511
     serialCom...
        (s,2,phase,amplitude,channelNum ...
        ,angleOffAxis,angleRotate,powermode)
     %控制每个阵元的幅度相位
        pause(1); % 暂停 1 秒
end