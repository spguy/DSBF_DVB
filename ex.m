% 均匀面阵波束形成
clear;clc;close all;
dx = 0.5;                               % x方向阵元间距,这里表示0.5λ
dy = 0.5;                               % y方向阵元间距,这里表示0.5λ
theta0 = -20;                           % 目标俯仰角度,-90~90
phi0 = 50;                              % 目标方位角度,-90~90
alpha_x = 2*pi*sind(phi0)*cosd(theta0);      % x方向相位差
alpha_y = 2*pi*sind(theta0);           % y方向相位差        
M = 20;                                 % x方向阵元数
N = 20;                                 % y方向阵元数                      
X = (0:1:M-1)*dx;                          % x方向阵列排布
Y = (0:1:N-1)*dy;                          % y方向阵列排布
X2=kron(ones(1,N),X);
Y2=kron(Y,ones(1,M));
 
figure;
plot(X2,Y2,'.');axis equal;grid on;
title('天线阵');xlabel('距离（m）');ylabel('距离（m）');
 
ax = exp(1i*X*alpha_x);                 % x方向导向矢量
ay = exp(1i*Y*alpha_y);                 % y方向导向矢量
axy = kron(ax,ay);                      % 矩形阵面导向矢量
 
 
dtheta = 0.2;
dphi = 0.2;                                 % 扫描角度间隔
theta_scan = -90:dtheta:90;                 % 俯仰扫描角度,-90~90
phi_scan = -90:dphi:90;                     % 方位扫描角度，-90~90
theta_len = length(theta_scan);
phi_len = length(phi_scan);
beam = zeros(theta_len, phi_len);           % 初始化波束
for i = 1:1:theta_len
    for j = 1:1:phi_len
        theta = theta_scan(i);
        phi = phi_scan(j);
        Fx = exp(1i*X*2*pi*sind(theta)*cosd(phi));
        Fy = exp(1i*Y*2*pi*sind(phi));
        Fxy = kron(Fx,Fy); 
        beam(i,j) = abs(((axy.')'*(Fxy.')));
    end
end
beam_db = 20*log10(beam/max(max(beam)));
 
figure;
mesh(phi_scan, theta_scan, beam_db);
title('矩形面阵方向图');
xlabel('俯仰角');ylabel('方位角');zlabel('幅度(dB)');
axis([-100 100 -100 100 -80 10]);
 
figure;
imagesc(theta_scan,phi_scan,beam_db);
colorbar;axis tight;shading interp;
xlabel('俯仰角');ylabel('方位角');zlabel('幅度(dB)');
title('矩形面阵方向图俯视');
 
figure;
plot(theta_scan,beam_db(1+(phi0+90)/0.2,:));           % 对应方位角度切面
xlabel('俯仰角/度');ylabel('幅度/dB');
grid on;hold on;
plot([theta0,theta0],ylim,'m-.');
title('俯仰面方向图');
axis([-100 100 -80 0]);
 
figure;
plot(phi_scan,beam_db(:,1+(theta0+90)/0.2));           % 对应俯仰角度切面
xlabel('方位角/度');ylabel('幅度/dB');
grid on;hold on;
plot([phi0,phi0],ylim,'m-.');
title('方位面方向图');
axis([-100 100 -80 0]);