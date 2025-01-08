function DVBS2BentPipeInit(modulationAndCodingMode, seed, ...
  ldpcFrameLength, selDPD, ulFreq, selLvlBO, gsTxAntDiam, dopplerFreq, ...
  filterSpanInSymbols, sampPerSym, altitude, satRxAntDiam, ...
  satRxNoiseFigure, chebyFilterOrder, satHPABackoff, dlFreq, ...
  satTxAntDiam, gsRxAntDiam, gsRxNoiseFigure, selPhNo, iqAmpImbal, ...
  iqPhImbal, dcOffsetPct, selCorrDCOffset, selCorrIQ, selCorrDoppler, ...
  LDPCNumIterations)
% BENTPIPEDVBS2INIT Set up workspace variables for the Bent Pipe DVBS2
% Link with RF Impairments and Corrections example
%
% Reference:  ETSI Standard EN 302 307-1 V1.4.1(2014-11). Digital Video
% Broadcasting (DVB); Second Generation Framing Structure, Channel Coding
% and Modulation Systems for Broadcasting, Interactive Services, News
% Gathering and other Broadband Satellite Applications (DVB-S2).

% Copyright 2021 The MathWorks, Inc.

systemInfo = regexp(modulationAndCodingMode, ' ', 'split');
modulationType = char(systemInfo(1));
paramRFSatLink.ModulationType = modulationType;
if strcmpi(modulationType,'QPSK')
  paramRFSatLink.modIdx = 1;
else  % 8PSK
  paramRFSatLink.modIdx = 2;
end
paramRFSatLink.CodeRate = char(systemInfo(2));
codeRate = str2num(paramRFSatLink.CodeRate); %#ok<ST2NM>
paramRFSatLink.ModulationType = modulationType;


paramRFSatLink.Rsym =  36e6; % 36e6;  % sym/s
fs = paramRFSatLink.Rsym * sampPerSym;  % sample rate in Hz
if strcmpi(modulationType,'QPSK')
  paramRFSatLink.BitPeriod = 1/(2*paramRFSatLink.Rsym);
else % 8PSK
  paramRFSatLink.BitPeriod = 1/(3*paramRFSatLink.Rsym);
end
paramRFSatLink.NumBytesPerPacket = 188;
byteSize = 8;
paramRFSatLink.NumBitsPerPacket = ... 
  paramRFSatLink.NumBytesPerPacket * byteSize;

%%  BCH coding
[paramRFSatLink.BCHCodewordLength, ...
  paramRFSatLink.BCHMessageLength, ...
  paramRFSatLink.BCHGeneratorPoly] = ...
  getbchparameters(codeRate,ldpcFrameLength);
if strcmpi(ldpcFrameLength,"Normal")
  BCHPrimPoly = 65581;  % primpoly(16,'min')
else  % "Short"
  BCHPrimPoly = 16427;  % primpoly(14,'min')
end
numBits = nextpow2(BCHPrimPoly);
msbFirst = true;
paramRFSatLink.BCHPrimitivePoly = int2bit(BCHPrimPoly,numBits,msbFirst)';
paramRFSatLink.NumPacketsPerBBFrame = ... 
  floor(paramRFSatLink.BCHMessageLength/paramRFSatLink.NumBitsPerPacket);
paramRFSatLink.NumInfoBitsPerCodeword = ... 
  paramRFSatLink.NumPacketsPerBBFrame*paramRFSatLink.NumBitsPerPacket;

%%  LDPC coding
if strcmpi(ldpcFrameLength,'Normal')
  paramRFSatLink.LDPCCodewordLength = 64800;%normal FECFRAME (nldpc = 64 800 bits) 
else  % short
  if strcmpi(modulationAndCodingMode,"8PSK 9/10")
    error(['When the code rate is 9/10, the LDPC frame length ' ...
           'must be Normal.']);
  end
  paramRFSatLink.LDPCCodewordLength = 16200;
end
paramRFSatLink.LDPCParityCheckMatrix = ...
  HelperDVBS2ldpc(codeRate,paramRFSatLink.LDPCCodewordLength);
paramRFSatLink.LDPCNumIterations = LDPCNumIterations;

% No interleaving (for QPSK)
paramRFSatLink.InterleaveOrder = (1:paramRFSatLink.LDPCCodewordLength).';

if strcmpi(modulationType, '8PSK')
  Ncol = 3;
  iTemp = reshape(paramRFSatLink.InterleaveOrder, ...
    paramRFSatLink.LDPCCodewordLength/Ncol, Ncol).';
  if codeRate == 3/5
    % Special Case - Figure 8
    iTemp = flipud(iTemp);
  end
  paramRFSatLink.InterleaveOrder = iTemp(:);
end

%%  Modulation
switch modulationType
  case 'QPSK'
    Ry = [+1; +1; -1; -1];
    Iy = [+1; -1; +1; -1];
    paramRFSatLink.Constellation = (Ry + 1i*Iy)/sqrt(2);
    paramRFSatLink.SymbolMapping = [0 2 3 1];
    paramRFSatLink.PhaseOffset = pi/4;
  case '8PSK'
    A = sqrt(1/2);
    Ry = [+A +1 -1 -A  0 +A -A  0].';
    Iy = [+A  0  0 -A  1 -A +A -1].';
    paramRFSatLink.Constellation = Ry + 1i*Iy;
    paramRFSatLink.SymbolMapping  = [1 0 4 6 2 3 7 5];
    paramRFSatLink.PhaseOffset = 0;
  otherwise
    error(message('comm:getParamsDVBS2Demo:ModulationUnsupported'));
end
numModLevels = length(paramRFSatLink.Constellation);
paramRFSatLink.BitsPerSymbol = log2(numModLevels);
paramRFSatLink.ModulationOrder = numModLevels;

% Number of symbols per codeword
paramRFSatLink.NumSymsPerCodeword = ... 
  paramRFSatLink.LDPCCodewordLength/paramRFSatLink.BitsPerSymbol;

% RF parameters for satellite and ground station receivers
paramRFSatLink.Seed = seed;
paramRFSatLink.SatRxNoiseFigure = satRxNoiseFigure;
paramRFSatLink.ChebyFilterOrder = chebyFilterOrder;
paramRFSatLink.GSRxNoiseFigure = gsRxNoiseFigure;

% Calculate the desired satellite AGC gain based on the backoff factor
IPsat = 0;  % dBm
agcDesPout = IPsat - satHPABackoff;  % dBm
paramRFSatLink.AGCDesPout = 10^((agcDesPout-30)/10);  % W

% Design Chebyshev filter
order = paramRFSatLink.ChebyFilterOrder;
pbRipple = 1;  % dB
fp = 0.6 * paramRFSatLink.Rsym; 
fnorm = 2*fp/fs;
[paramRFSatLink.ChebyNumerator,paramRFSatLink.ChebyDenominator] = ...
  cheby1(order,pbRipple,fnorm);

% Table-based amplifier, based on the curve in Figure H.12 of ETSI EN 302
% 307, V1.1.1
paramRFSatLink.ampTable = [-20, -13.1, 0; ...
                           -18, -11.2, 1; ...
                           -16, -9.3,  2; ...
                           -14, -7.4,  4; ...
                           -12, -5.5,  7; ...
                           -10, -3.9, 11; ...
                            -8, -2.6, 15; ...
                            -6, -1.4, 22; ...
                            -4, -0.7, 27; ...
                            -2, -0.2, 35; ...
                             0,  0.0, 43; ...
                             2, -0.2, 50; ...
                             4, -0.6, 58; ...
                             6, -1.0, 64];  % original values
% Scale input and output powers so that the linear gain is 30 dB, and the
% input saturation power is 0 dBm.  Scale the AM/PM so that it has both
% negative and positive shifts.
origLinGain = paramRFSatLink.ampTable(1,2) - ...
  paramRFSatLink.ampTable(1,1);  % dB
desLinGain = 30;  % dBm
paramRFSatLink.ampTable(:,2) = ...
  paramRFSatLink.ampTable(:,2) + desLinGain - origLinGain;
paramRFSatLink.ampTable(:,3) = paramRFSatLink.ampTable(:,3) - 20;

% Delays
paramRFSatLink.RecDelayPreBCH = paramRFSatLink.BCHMessageLength;

% Account for delay by Chebyshev Type 1 satellite filter which
% introduces delay of 7 (upsampled) samples, which reduces to 1
% sample/symbol after Rx Pulse Shaping filter
chebyDelay = 1;  % samples
paramRFSatLink.FilterSpanInSymbols = filterSpanInSymbols;
paramRFSatLink.RxFilterDelay = paramRFSatLink.LDPCCodewordLength - ...
  ((paramRFSatLink.FilterSpanInSymbols + chebyDelay) * ...
  paramRFSatLink.BitsPerSymbol);

paramRFSatLink.Altitude = altitude;
paramRFSatLink.UplinkFrequency = ulFreq;
paramRFSatLink.SamplesPerSymbol = sampPerSym; 
paramRFSatLink.DownlinkFrequency = dlFreq;
paramRFSatLink.preDistortion = selDPD;
paramRFSatLink.resetBER = 0;

% Update the input gain and output gain for HPA block (memoryless
% nonlinearity)
[paramRFSatLink.GindB,paramRFSatLink.GoutdB] = updateHPA(selLvlBO);

% Update the doppler impairment parameter
paramRFSatLink.DoppOffset = dopplerFreq;

% Amplitude and phase imbalances
paramRFSatLink.IQAmpImbal = iqAmpImbal;
paramRFSatLink.IQPhImbal = iqPhImbal;

% DC offset
paramRFSatLink.DCOffsetPct = dcOffsetPct;

% Phase noise
tmpNoise = [-100 -55 -48];
paramRFSatLink.PhaseNoise = tmpNoise(selPhNo);

% Enable/disable DC blocker
paramRFSatLink.DCBlock = logical(selCorrDCOffset);

% Enable/disable carrier synchronizer
paramRFSatLink.CarrierSync = logical(selCorrDoppler);
if paramRFSatLink.CarrierSync
  set_param([bdroot '/RF Corrections/Doppler Correction/Carrier ' ...
                    'Synchronizer'],'Modulation', ...
                    paramRFSatLink.ModulationType);
end

% Enable/disable I/Q imbalance compensation
paramRFSatLink.IQComp = logical(selCorrIQ);

% Set antenna gains
neff= 0.55; % middle of the road efficiency
GHz2Hz = 1e9;
term1 = sqrt(neff)*pi*GHz2Hz/physconst("Lightspeed");
paramRFSatLink.gsTxAntGain = term1*gsTxAntDiam*ulFreq;  % Proakis pg. 316
paramRFSatLink.satRxAntGain = term1*satRxAntDiam*ulFreq;
paramRFSatLink.satTxAntGain = term1*satTxAntDiam*dlFreq;
paramRFSatLink.gsRxAntGain = term1*gsRxAntDiam*dlFreq;

% Set the fixed satellite front end gain.  Set it to a bit less than the
% free space path loss value.
ulFSPL = 4*pi*(altitude*1e3)*(ulFreq*1e9)/physconst("Lightspeed");
paramRFSatLink.satFrontEndGain = 0.9*ulFSPL;

paramRFSatLink.LDPCLinkRecDelay = paramRFSatLink.BCHCodewordLength;

paramRFSatLink.FullLinkRecDelay = ...
  2 * paramRFSatLink.NumInfoBitsPerCodeword;

assignin('base', 'paramRFSatLink', paramRFSatLink);
end

function [nBCH, kBCH, genBCH] = getbchparameters(R,ldpcFrameLength)

if strcmpi(ldpcFrameLength,"Normal")
  table5a = [1/4  16008 16200 12 64800
    1/3  21408 21600 12 64800
    2/5  25728 25920 12 64800
    1/2  32208 32400 12 64800
    3/5  38688 38880 12 64800
    2/3  43040 43200 10 64800
    3/4  48408 48600 12 64800
    4/5  51648 51840 12 64800
    5/6  53840 54000 10 64800
    8/9  57472 57600  8 64800
    9/10 58192 58320  8 64800];

  rowidx = find(abs(table5a(:,1)-R)<.001);
  kBCH = table5a(rowidx,2);
  nBCH = table5a(rowidx,3);
  tBCH = table5a(rowidx,4);

  % Generate BCH polynomials from Table 6a of ETSI EN 302 307, V1.1.1
  g{1} = commstr2poly('1+x2+x3+x5+x16');
  g{2} = commstr2poly('1+x+x4+x5+x6+x8+x16');
  g{3} = commstr2poly('1+x2+x3+x4+x5+x7+x8+x9+x10+x11+x16');
  g{4} = commstr2poly('1+x2+x4+x6+x9+x11+x12+x14+x16');
  g{5} = commstr2poly('1+x+x2+x3+x5+x8+x9+x10+x11+x12+x16');
  g{6} = commstr2poly('1+x2+x4+x5+x7+x8+x9+x10+x12+x13+x14+x15+x16');
  g{7} = commstr2poly('1+x2+x5+x6+x8+x9+x10+x11+x13+x15+x16');
  g{8} = commstr2poly('1+x+x2+x5+x6+x8+x9+x12+x13+x14+x16');

  tmpPoly = 1;
  for idx = 1:8
    tmpPoly = mod(conv(tmpPoly,g{idx}),2);
  end
  a8 = fliplr(tmpPoly);

  g{9} = commstr2poly('1+x5+x7+x9+x10+x11+x16');
  g{10} = commstr2poly('1+x+x2+x5+x7+x8+x10+x12+x13+x14+x16');
  for idx = 9:10
    tmpPoly = mod(conv(tmpPoly,g{idx}),2);
  end
  a10 = fliplr(tmpPoly);

  g{11} = commstr2poly('1+x2+x3+x5+x9+x11+x12+x13+x16');
  g{12} = commstr2poly('1+x+x5+x6+x7+x9+x11+x12+x16');
  for idx = 11:12
    tmpPoly = mod(conv(tmpPoly,g{idx}),2);
  end
  a12 = fliplr(tmpPoly);

  switch tBCH
    case 8
      genBCH = a8;
    case 10
      genBCH = a10;
    case 12
      genBCH = a12;
  end
  
else  % "Short"
  table5b = [1/4  3072  3240 12 16200
    1/3  5232  5400 12 16200
    2/5  6312  6480 12 16200
    1/2  7032  7200 12 16200
    3/5  9552  9720 12 16200
    2/3 10632 10800 12 16200
    3/4 11712 11880 12 16200
    4/5 12432 12600 12 16200
    5/6 13152 13320 12 16200
    8/9 14232 14400 12 16200];

  rowidx = find(abs(table5b(:,1)-R)<.001);
  kBCH = table5b(rowidx,2);
  nBCH = table5b(rowidx,3);

  % Generate BCH polynomials from Table 6b of ETSI EN 302 307, V1.1.1
  g{1} = commstr2poly('1+x+x3+x5+x14');
  g{2} = commstr2poly('1+x6+x8+x11+x14');
  g{3} = commstr2poly('1+x+x2+x6+x9+x10+x14');
  g{4} = commstr2poly('1+x4+x7+x8+x10+x12+x14');
  g{5} = commstr2poly('1+x2+x4+x6+x8+x9+x11+x13+x14');
  g{6} = commstr2poly('1+x3+x7+x8+x9+x13+x14');
  g{7} = commstr2poly('1+x2+x5+x6+x7+x10+x11+x13+x14');
  g{8} = commstr2poly('1+x5+x8+x9+x10+x11+x14');
  g{9} = commstr2poly('1+x+x2+x3+x9+x10+x14');
  g{10} = commstr2poly('1+x3+x6+x9+x11+x12+x14');
  g{11} = commstr2poly('1+x4+x11+x12+x14');
  g{12} = commstr2poly('1+x+x2+x3+x5+x6+x7+x8+x10+x13+x14');
  genBCH = 1;
  for idx = 1:12
    genBCH = mod(conv(genBCH,g{idx}),2);
  end
  genBCH = fliplr(genBCH);
  
end
end

%*********************************************************************
% Function Name:     updateHPA
% Description:       update nonlinear amplifier input and output gains
%********************************************************************
function [GindB, GoutdB] = updateHPA(selLvlBO)

% Update the saturation level parameters
valsBO = [-30 -7 -1];       % values for backoff
rrcComp = 20*log10(.38);    % compensation for RRC filter P2P power
gainLin = 18;               % fixed HPA linear gain
alpha = 20*log10(2.1587);   % difference between linear gain and
                            % small signal gain
sps = 8;                    % samples per symbol
rctGain = 10*log10(sps);    % raised cosine filter gain

gainIP = valsBO - rrcComp - rctGain;
GindB = gainIP(selLvlBO);
gainOP = -valsBO + rrcComp - alpha + gainLin;
GoutdB = gainOP(selLvlBO);
end
% EOF
