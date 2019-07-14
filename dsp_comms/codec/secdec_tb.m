dbgEn = 1;
rngSeed = 1;
nDataBits = 13;
nPackets = 10000;
% nPackets = 100;

rng(rngSeed);

% Hamming
P_hamming = [
    1 1 0;
    0 1 1;
    1 1 1;
    1 0 1];
G_hamming = [eye(4), P_hamming];
H_hamming = [P_hamming', eye(3)];

dmin_hamming_par = gfweight(H_hamming,'par');
dmin_hamming_gen = gfweight(G_hamming,'gen');
fprintf('Hamming d_min (PAR): %d\n', dmin_hamming_par);
fprintf('Hamming d_min (GEN): %d\n', dmin_hamming_gen);

% SECDED
P_secded = [
    1	0	0	0	1	1;
    1	0	0	1	0	1;
    1	0	0	1	1	0;
    0	0	0	1	1	1;
    1	0	1	0	0	1;
    1	0	1	0	1	0;
    0	0	1	0	1	1;
    1	0	1	1	0	0;
    0	0	1	1	0	1;
    0	0	1	1	1	0;
    1	0	1	1	1	1;
    1	1	0	0	0	1;
    1	1	0	0	1	0
];
G_secded = [P_secded, eye(13)];
H_secded = [P_secded', eye(6)];
dmin_secded_par = gfweight(H_secded,'par');
dmin_secded_gen = gfweight(G_secded,'gen');
fprintf('SECDED d_min  (PAR): %d\n', dmin_secded_par);
fprintf('SECDED d_min  (GEN): %d\n', dmin_secded_gen);

% Hamming
m_hamming = 5;
n_hamming = 2^m_hamming - 1;
k_hamming = n_hamming - m_hamming;
% TODO: with polynomial
% H_hamming = hammgen(m);
H_dec = 1:2^m_hamming-1;
H_bin = de2bi(H_dec).';
P_hamming = H_bin(:, setdiff(1:2^m_hamming-1, 2.^(0:m_hamming-1))).';
G_hamming = [eye(k_hamming), P_hamming];
H_hamming = [P_hamming.', eye(m_hamming)];
parityPos = zeros(2^m_hamming-1, 1);
parityPos(2.^(0:m_hamming-1)) = 1;
syndromeLut_hamming = zeros(2^m_hamming-1, 1);
for idx = 1:2^m_hamming-1
    syndromeLut_hamming(idx) = idx - sum(parityPos(1:idx));
end
syndromeLut_hamming(2.^(0:m_hamming-1)) = 0;
% syndromeLut_hamming = syndromeLut_hamming(1:k_hamming);

% SECDED
k_secded = 13;
n_secded = 19;
m_secded = 5;
P_secded = P_hamming(1:k_secded, :);
H_secded = ...
    [P_secded.', zeros(m_secded,1), eye(m_secded);
    ones(1, n_secded)];
syndromeLut_secded = syndromeLut_hamming;
dmin_secded_par = gfweight(H_secded,'par');

testCase = 1; % 0: Manually inject bit error; 1: 
tcConfig.blockEncEn = 1;
tcConfig.encSel = {'Hamming', 'SECDED'};
switch testCase
    case 0
        snr_dB = 0;
        tcConfig.errMode = {'manual'};
        tcConfig.errPosMode = {'rand'};
        tcConfig.errPos = 1;
        tcConfig.errNum = [0:4];
%         tcConfig.errNum = 1;
    case 1
        snr_dB = 0:2:10;
        tcConfig.errMode = {'demod'};
        tcConfig.errPosMode = {'rand'};
        tcConfig.errPos = 1;
        tcConfig.errNum = 0;
end

%%%% Run sims
configSet = genVerifDataConfigExpand(tcConfig);
nSim = numel(configSet);
simStr = cell(nSim, 1);
n0 = 1;
Eb = 10.^(snr_dB/10)*n0;
nSnr = numel(snr_dB);
per = zeros(nSim, nSnr);
ber = zeros(nSim, nSnr);
ecr = cell(nSim, 1);
edr = cell(nSim, 1);
err = cell(nSim, 1);

for iSim = 1:nSim
    config = configSet{iSim};
    
    %%%% Run codec
    if config.blockEncEn
        switch config.encSel{1}
            case 'Hamming'
                nDataBits = k_hamming;
                nEncBits = n_hamming;
            case 'SECDED'
                nDataBits = k_secded;
                nEncBits = n_secded;
        end
    else
        nEncBits = nDataBits;
    end
    
    nPacketErr = zeros(nSnr, 1);
    nBitErr = zeros(nSnr, 1);
    nDetBitErr = zeros(nSnr, nEncBits+1);
    nCorBitErr = zeros(nSnr, nEncBits+1);
    nRefBitErr = zeros(nSnr, nEncBits+1); % Number of packets with 1:nEncBits bit errors
    
    for iSnr = 1:nSnr
        tStart = tic;
        fprintf('\n## SNR: %.2f dB\n', snr_dB(iSnr));
        
        for iPacket = 1:nPackets
            %%%% Encoding
            if config.blockEncEn
                switch config.encSel{1}
                    case 'Hamming'
                        dataBits = randi([0 1], 1, nDataBits);
                        encBits = mod(dataBits*G_hamming, 2);
                        H = H_hamming;
                        syndromeLut = syndromeLut_hamming;
                    case 'SECDED'
                        dataBits = randi([0 1], 1, nDataBits);
                        parityBits = mod(dataBits*P_secded, 2);
                        encBits = [dataBits, mod(sum([dataBits, parityBits]), 2), parityBits];
                        H = H_secded;
                        syndromeLut = syndromeLut_secded;
                end
            else
                encBits = randi([0 1], nDataBits, 1);
            end
            R = nDataBits/nEncBits;
            if dbgEn
                fprintf('Input bits     : %s\n', sprintf('%d,', dataBits));
                fprintf('Encoded bits   : %s\n', sprintf('%d,', encBits));
            end
            %%%% Modulation
            symTx = encBits*2-1;

            %%%% AWGN
            Es = Eb*R;
            amp = sqrt(Es(iSnr));
            sigRx = amp*symTx + sqrt(n0/2)*randn(size(symTx));
            
            %%%% Demod
            switch config.errMode{1}
                case 'manual'
                    decIn = encBits;
                    if strcmp(config.errPosMode{1}, 'rand')
                        posShuffle = randperm(nEncBits);
                        config.errPos = sort(posShuffle(1:config.errNum));
                    end
                    decIn(config.errPos) = ~decIn(config.errPos);
                case 'demod'
                    decIn = (sigRx >= 0);
            end
            errRef = (decIn~=encBits);
            errPosRef = find(errRef==1);
            nBitErrRef = sum(errRef);
            
            %%%% Debug info
            if dbgEn
                fprintf('Demod bits     : %s\n', sprintf('%d,', decIn));
                fprintf('# Error Reference\n');
%                 fprintf('Error          : %s\n', sprintf('%d, ', errRef));
                fprintf('Position   : %s\n', sprintf('%d, ', errPosRef));
                fprintf('Number     : %d\n', nBitErrRef);
            end
            
            %%%% Decoding
            if config.blockEncEn
                syndromeBits = mod(decIn*H.', 2);
                switch config.encSel{1}
                    case 'Hamming'
                        syndrome = bi2de(syndromeBits);
                        if syndrome == 0
                            errPos = 0;
                            status = 0;
                            nBitErrDet = 0;
                        else
                            errPos = syndromeLut(syndrome);
                            errPos = errPos(errPos<=k_hamming);
                            status = 1;
                            nBitErrDet = 1;
                        end
                    case 'SECDED'
                        syndrome = bi2de(syndromeBits(1:end-1));
                        if syndromeBits(end) == 0
                            errPos = 0;
                            if syndrome == 0
                                % No error
                                status = 0;
                                nBitErrDet = 0;
                            else
                                % Double or more errors
                                status = 2;
                                nBitErrDet = 2;
                            end
                        else
                            % Single error
                            if syndrome == 0
                                % Error in overall parity bit
                                errPos = 0;
                            else
                                % Errors could be in other parity bits
                                errPos = syndromeLut(syndrome);
                                errPos = errPos(errPos<=k_secded);
                            end
                            status = 1;
                            nBitErrDet = 1;
                        end
                end
                decBits = decIn;
                % Error correction
                if sum(errPos) ~= 0
                    decBits(errPos) = ~decIn(errPos);
                end
            else
                decBits = decIn;
            end
            
            %%%% Check results
            % Only compare data bits
            errDec = (decBits(1:nDataBits)~=dataBits);
            errPosDec = find(errDec==1);
            nBitErrDec = sum(errDec);
            if dbgEn
                fprintf('Decoded bits   : %s\n', sprintf('%d,', decBits));
                fprintf('# Error Decoded\n');
%                 fprintf('Error      : %s\n', sprintf('%d, ', errDec));
                fprintf('Position   : %s\n', sprintf('%d, ', errPosDec));
                fprintf('Number     : %d\n', nBitErrDec);
            end
            nPacketErr(iSnr) = nPacketErr(iSnr) + (nBitErrDec~=0);
            nBitErr(iSnr) = nBitErr(iSnr) + nBitErrDec;
            nCorBitErr(iSnr, nBitErrRef+1) = nCorBitErr(iSnr, nBitErrRef+1) + (nBitErrDec==0);
            nDetBitErr(iSnr, nBitErrRef+1) = nDetBitErr(iSnr, nBitErrRef+1) + (nBitErrDet==nBitErrRef);
            nRefBitErr(iSnr, nBitErrRef+1) = nRefBitErr(iSnr, nBitErrRef+1) + 1;
        end       
        per(iSim, iSnr) = nPacketErr(iSnr)/nPackets;
        ber(iSim, iSnr) = nBitErr(iSnr)/nDataBits/nPackets;
        ecr{iSim}(iSnr, :) = nCorBitErr(iSnr, :)./nRefBitErr(iSnr, :);
        edr{iSim}(iSnr, :) = nDetBitErr(iSnr, :)./nRefBitErr(iSnr, :);
        err{iSim}(iSnr, :) = nRefBitErr(iSnr, :)/nPackets;

        if dbgEn
            fprintf('# Error Decoded\n');
            fprintf('Error occurrence rate  : %s\n', sprintf('%f, ', err{iSim}(iSnr, :)));
            fprintf('Error correction rate  : %s\n', sprintf('%f, ', ecr{iSim}(iSnr, :)));
            fprintf('Error detection rate   : %s\n', sprintf('%f, ', edr{iSim}(iSnr, :)));
            fprintf('PER    : %f\n', per(iSim, iSnr));
            fprintf('BER    : %f\n', ber(iSim, iSnr));
        end
        fprintf('## SNR %.2f dB time    : %f\n', snr_dB(iSnr), toc(tStart));
    end
    
    switch config.errMode{1}
        case 'manual'
            simStr{iSim} = strrep(sprintf('nDataBits=%d, blockEncEn=%d, encSel=%s, errMode=%s, errPosMode=%s, config.errNum=%d', ...
                nDataBits, config.blockEncEn, config.encSel, config.errMode{1}, config.errPosMode{1}, config.errNum), '_', '\_');
        case 'demod'
            simStr{iSim} = strrep(sprintf('nDataBits=%d, blockEncEn=%d, encSel=%s, errMode=%s', ...
                nDataBits, config.blockEncEn, config.encSel{1}, config.errMode{1}), '_', '\_');
    end
    fprintf('#### %s completed.\n', simStr{iSim});
end

%%%% Display results
% Plot configurations
defaultAxesColorOrder = [0 0 1; 1 0 0; 0 1 0; 0,1,1; 1,0,1];
lineStyle = {'-', '--', '-.', ':'};
markerStyle = {'o', '*', 's', 'x', '^', '+'};
[lineStyleOrder, markerStyleOrder] = meshgrid(lineStyle, markerStyle);
defaultAxesLineStyleOrder = strcat(lineStyleOrder(:), markerStyleOrder(:));
legLoc = 'southwest';
defaultLineLineWidth = 2;
defaultLineMarkerSize = 8;
titleStr = strrep(sprintf(': nPackets_%d', nPackets), '_', '\_');

% PER
figure;
set(gcf, 'DefaultAxesColorOrder', defaultAxesColorOrder);
set(gcf, 'defaultAxesLineStyleOrder', defaultAxesLineStyleOrder);
set(gcf, 'defaultLineLineWidth', defaultLineLineWidth);
set(gcf, 'defaultLineMarkerSize', defaultLineMarkerSize);
for iSim = 1:nSim
    semilogy(snr_dB, per(iSim, :));
    hold on;
end
xlabel('Eb/n0 (dB)');
legObj = legend(simStr);
set(legObj, 'interpreter', 'none', 'Location', legLoc);
title(strcat('PER', titleStr));
figSizeAdj(gcf, 2);
grid on;

% BER
figure;
set(gcf, 'DefaultAxesColorOrder', defaultAxesColorOrder);
set(gcf, 'defaultAxesLineStyleOrder', defaultAxesLineStyleOrder);
set(gcf, 'defaultLineLineWidth', defaultLineLineWidth);
set(gcf, 'defaultLineMarkerSize', defaultLineMarkerSize);
for iSim = 1:nSim
    semilogy(snr_dB, ber(iSim, :));
    hold on;
end
xlabel('Eb/n0 (dB)');
legObj = legend(simStr);
set(legObj, 'interpreter', 'none', 'Location', legLoc);
title(strcat('BER', titleStr));
figSizeAdj(gcf, 2);
grid on;

% ERR
figure;
set(gcf, 'DefaultAxesColorOrder', defaultAxesColorOrder);
set(gcf, 'defaultAxesLineStyleOrder', defaultAxesLineStyleOrder);
set(gcf, 'defaultLineLineWidth', defaultLineLineWidth);
set(gcf, 'defaultLineMarkerSize', defaultLineMarkerSize);
legStr = {};
for iSim = 1:nSim
    for iSnr = 1:numel(snr_dB)
        semilogy(err{iSim}(iSnr, :));
        hold on;
        legStr{end+1} = strcat(simStr{iSim}, sprintf(', SNR=%.2f', snr_dB(iSnr)));
    end
end
xlabel('Number Of Bit Errors');
legObj = legend(legStr);
set(legObj, 'interpreter', 'none', 'Location', legLoc);
title(strcat('Error Reference Ratio', titleStr));
figSizeAdj(gcf, 2);
grid on;

% ECR
figure;
set(gcf, 'DefaultAxesColorOrder', defaultAxesColorOrder);
set(gcf, 'defaultAxesLineStyleOrder', defaultAxesLineStyleOrder);
set(gcf, 'defaultLineLineWidth', defaultLineLineWidth);
set(gcf, 'defaultLineMarkerSize', defaultLineMarkerSize);
legStr = {};
for iSim = 1:nSim
    for iSnr = 1:numel(snr_dB)
        semilogy(ecr{iSim}(iSnr, :));
        hold on;
        legStr{end+1} = strcat(simStr{iSim}, sprintf(', SNR=%.2f', snr_dB(iSnr)));
    end
end
xlabel('Number Of Bit Errors');
legObj = legend(legStr);
set(legObj, 'interpreter', 'none', 'Location', legLoc);
title(strcat('Error Correction Rate', titleStr));
figSizeAdj(gcf, 2);
grid on;

% EDR
figure;
set(gcf, 'DefaultAxesColorOrder', defaultAxesColorOrder);
set(gcf, 'defaultAxesLineStyleOrder', defaultAxesLineStyleOrder);
set(gcf, 'defaultLineLineWidth', defaultLineLineWidth);
set(gcf, 'defaultLineMarkerSize', defaultLineMarkerSize);
legStr = {};
for iSim = 1:nSim
    for iSnr = 1:numel(snr_dB)
        plot(edr{iSim}(iSnr, :));
        hold on;
        legStr{end+1} = strcat(simStr{iSim}, sprintf(', SNR=%.2f', snr_dB(iSnr)));
    end
end
xlabel('Number Of Bit Errors');
legObj = legend(legStr);
set(legObj, 'interpreter', 'none', 'Location', legLoc);
title(strcat('Error Detection Rate', titleStr));
figSizeAdj(gcf, 2);
grid on;

return;
