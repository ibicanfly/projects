%%%% Sim configurations
dbgEn = 0;
rngSeed = 1;
% snr_dB = 10;
snr_dB = 0:1:10;
nBits = 20;
nPackets = 100;
% nBits = 160;
% nPackets = 10000;

%%%% Algorithm configurations
tcConfig.convType = [0 1];
% tcConfig.convType = [0];
tcConfig.modType = {'BPSK', 'BPM-BPSK'};
% tcConfig.modType = {'BPSK'};
tcConfig.encMode = [1 0]; % 0: Non-terminated; 1: Terminated; 2: Tail-biting; 3: Pucturated
tcConfig.decRandInitStateEn = 0; % 0: Random state; 1: Assigned state
tcConfig.traceBackLenMode = 0; % 0: Max; 1: 5*m; 2: 3*m; 3: m
tcConfig.quantEn = 0;

%%%% Configure
rng(rngSeed);


configSet = genVerifDataConfigExpand(tcConfig);
nSim = numel(configSet);
simStr = cell(nSim, 1);
n0 = 1;
Eb = 10.^(snr_dB/10)*n0;
Es = Eb*R;
nSnr = numel(snr_dB);
per = zeros(nSim, nSnr);
ber = zeros(nSim, nSnr);

for iSim = 1:nSim
    config = configSet{iSim};

    switch config.convType
        case 0
            genPolyOct = [7, 5];
    %         genPolyOct = [23 35 0; 0 5 13];
        case 1
            genPolyOct = [2, 5];
        case 2
            genPolyOct = [133, 171];
        otherwise
            error('Invalid convType.');
    end
    genPolyStr = sprintf('[ %s]', sprintf('%d ', genPolyOct));
    [k, n] = size(genPolyOct);
    R = k/n;

    genPolyBin = fliplr(de2bi(oct2dec(genPolyOct)));
    v = zeros(k, 1);
    for idxIn = 1:k
        v(idxIn) = nextpow2(max(oct2dec(genPolyOct(idxIn, :)))) - 1;
    end
    vTot = sum(v);
    m = max(v);
    for idxIn = 1:k
        for idxOut = 1:n
            genPolyBin((idxOut-1)*k+idxIn, :) = circshift(genPolyBin((idxOut-1)*k+idxIn, :), v(idxIn)-m);
        end
    end

    %%%% Trellis generation
    % Reference
    trellis = poly2trellis(v+1, genPolyOct);

    [nextStateLut, outputLut, prevStateLut, prevOutputLut, stateInBitLut, stateOutBitLut] = ...
        genConvTrellis(k, n, v, m, vTot, genPolyBin, dbgEn);

    if ~isequal(trellis.nextStates, nextStateLut)
        error('Next states mismatch.');
    end
    if ~isequal(trellis.outputs, outputLut)
        error('Outputs mismatch.');
    end
    switch config.modType{1}
        case 'BPSK'
            bitMapping = [1 1; 1 -1; -1 1; -1 -1];
        case 'BPM-BPSK'
            bitMapping = [1 0; -1 0; 0 1; 0 -1]*sqrt(2);
        otherwise
            bitMapping = [1; -1];
    end
    nBitPerSym = size(bitMapping, 2);

    nSmp = ceil(nBits/k);
    switch config.encMode
        case {0, 1} % No termination
            stateInit = 0;
        case 2 % TODO: Tail-biting
            stateInit = 0;
        case 3 % TODO: Puncturated
            stateInit = 0;
        otherwise
            error('Invalid encoding mode.');
    end        

    %%%% Run sim
    nPacketErr = zeros(nSnr, 1);
    nBitErr = zeros(nSnr, 1);
    for iSnr = 1:nSnr
        tStart = tic;
        fprintf('\n## SNR: %.2f dB\n', snr_dB(iSnr));
        for iPacket = 1:nPackets
            if dbgEn
                fprintf('# SNR: %.2f dB, Packet [%d]\n', snr_dB(iSnr), iPacket);
            end

            %%%% Encoding
            inRawBits = randi([0 1], nBits, 1);
            switch config.encMode
                case 0 % No termination
                    nEncSmp = nSmp;
                    nTail = 0;
                    inBits = inRawBits;
                    encModeStr = 'No Termination';
                case 1 % Termination
                    nEncSmp = nSmp + m;
                    nTail = m;
                    inBits = [inRawBits; zeros(k*m, 1)];
                    encModeStr = 'Termination';
                case 2 % TODO: Tail-biting
                    nEncSmp = nSmp + m;
                    nTail = 0;
                    inBits = [inRawBits];
                    encModeStr = 'Tail Biting';
                case 3 % TODO: Puncturated
                    encModeStr = 'Puncturation';
                otherwise
                    error('Invalid encoding mode.');
            end
            tEnc = tic;
            [encBits] = conv_enc(inBits, nEncSmp, stateInit, k, n, nextStateLut, outputLut);
            if dbgEn
                fprintf('Encoding time  : %f\n', toc(tEnc));
            end

            % Verification
            encBitsRef = convenc(inBits, trellis);
            if ~isequal(encBitsRef, encBits)
                error('Encoded bits mismatch.');
            else
    %             fprintf('Encoded bits match.\n');
            end

            %%%% Symbol mapping
            tCh = tic;
            idxBitMapping = bi2de(reshape(encBits, nBitPerSym, []).', 'left-msb') + 1;
            symTx = reshape(bitMapping(idxBitMapping, :).', 1, []).';
            amp = sqrt(Es(iSnr));
            sigRx = amp*symTx + sqrt(n0)*randn(size(symTx));
            if config.quantEn
                %%%% AGC
                % Fixed gain
                quantLim = max(abs(sigRx));

                %%%% Quantization
                nQuantBits = 4;
                sigRxQuant = round(sigRx*2^(nQuantBits-1))/2^(nQuantBits-1);
            else
                sigRxQuant = sigRx;
            end
            if dbgEn
                fprintf('Input bits : %s\n', sprintf('%5d, ', inBits));
                fprintf('Enc bits   : %s\n', sprintf('%5d, ', encBits));
                fprintf('TX symbols : %s\n', sprintf('%5d, ', symTx));
                fprintf('RX signals : %s\n', sprintf('%5.2f, ', sigRxQuant));
            end
            if dbgEn
                fprintf('Channel time   : %f\n', toc(tCh));
            end

            %%%% Decoding
            tDec = tic;
            switch config.traceBackLenMode
                case 0
                    nPathTraceBack = nEncSmp;
                case 1
                    nPathTraceBack = 5*m;
                case 2
                    nPathTraceBack = 3*m;
                case 2
                    nPathTraceBack = m;
                otherwise
                    error('ERROR! Invalid TraceBack mode.');
            end
            nDecSmp = nEncSmp;
            nPathTraceBack = max(nPathTraceBack, nDecSmp);
            [decBits] = conv_dec(sigRx, config.encMode, config.decRandInitStateEn, nDecSmp, nPathTraceBack, stateInit, k, n, vTot, ...
                bitMapping, prevStateLut, prevOutputLut, stateInBitLut, inBits, dbgEn);
            if dbgEn
                fprintf('Decoding time: %f\n', toc(tDec));
            end

            %%%% Check results
            nPacketErr(iSnr) = nPacketErr(iSnr) + (isequal(decBits(1:end-nTail*k), inBits(1:end-nTail*k))==0);
            nBitErr(iSnr) = nBitErr(iSnr) + sum((decBits(1:end-nTail*k)~=inBits(1:end-nTail*k)));
        end
        per(iSim, iSnr) = nPacketErr(iSnr)/nPackets;
        ber(iSim, iSnr) = nBitErr(iSnr)/nBits/nPackets;

        fprintf('## SNR %.2f dB time    : %f\n', snr_dB(iSnr), toc(tStart));
    end

    simStr{iSim} = strrep(sprintf('%s, %s, %s, TraceBack=%d', genPolyStr, config.modType{1}, encModeStr, nPathTraceBack), '_', '\_');
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
titleStr = strrep(sprintf(': nBits_%d, nPackets_%d', nBits, nPackets), '_', '\_');

% PER
figure;
set(gcf, 'DefaultAxesColorOrder', defaultAxesColorOrder);
set(gcf, 'defaultAxesLineStyleOrder', defaultAxesLineStyleOrder);
set(gcf, 'defaultLineLineWidth', defaultLineLineWidth)
set(gcf, 'defaultLineMarkerSize', defaultLineMarkerSize)
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
set(gcf, 'defaultLineLineWidth', defaultLineLineWidth)
set(gcf, 'defaultLineMarkerSize', defaultLineMarkerSize)
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

return;

 