function [outputArg1,outputArg2] = serialCom( ...
    s,orderType,phase,amplitude,channelNum, ...
    angleOffAxis,angleRotate,powermode)
phase = floor(phase/5.625);%步长为5.625°

angleOffAxis = 100*angleOffAxis;
angleRotate = 100*angleRotate;

write(s,170,"uint8")%AA帧头
write(s,orderType,"uint8")%命令符
switch orderType
    case 2
        write(s,channelNum,"uint16")
        write(s,phase,"uint8")
        write(s,amplitude,"uint8")
        write(s,0,"uint16")
    case 8,9;
        write(s,13700,"uint16")%频率为13.7Mhz
        write(s,angleOffAxis,"uint16")%离轴角
        write(s,angleRotate,"uint16")%旋转角
    case 12
        write(s,channelNum,"uint16")
        write(s,0,"uint16")
        write(s,powermode,"uint8")
        write(s,0,"uint8")
    otherwise
        write(s,0,"uint16")
        write(s,0,"uint16")
        write(s,0,"uint16")
end
write(s,0,"uint32")
write(s,0,"uint16")
write(s,0,"uint8")
write(s,85,"uint8")%尾帧55
end