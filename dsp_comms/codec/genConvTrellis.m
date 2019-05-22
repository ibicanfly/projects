function [nextStateLut, outputLut, prevStateLut, prevOutputLut, stateInBitLut, stateOutBitLut] = ...
    genConvTrellis(k, n, v, m, vTot, genPolyBin, dbgEn)
%Generate trellis for convolutional code
% State: s_{u_k+u_(k-1)+...+u_1}, s_{u_k+u_(k-1)+...+u_1-1}, ..., s_{u_(k-1)+...+u_1+1}, ..., s_{u_1+u_2}, ..., s_{u_1+1}, s_{u_1}, ..., s_1, left-MSB
% In 1: s_{u_1}, s_{u_1-1}, ..., s_1
% In 2: s_{u_1+u_2}, s_{u_1+u_2-1}, ..., s_{u_1+1}
% ...
% In k: s_{u_k+u_(k-1)+...+u_1}, s_{u_k+u_(k-1)+...+u_1-1}, ..., s_{u_(k-1)+...+u_1+1}
% Inputs: (u_1, ..., u_k), left-MSB
% u_1
% ...
% u_k
% Outputs: (v_1, ..., v_n), left-MSB
% v_1
% ...
% v_n

fprintf('#### Trellis generation\n');
nState = 2^vTot;
nextStateLut = zeros(nState, 2^k);
outputLut = zeros(nState, 2^k);
prevStateLut = zeros(nState, 2^k);
prevOutputLut = zeros(nState, 2^k);
for iState = 1:nState
    state = iState - 1;
    % Current state
    stateSeqBits = de2bi(state); % Right MSB
    currStateBits = zeros(k, m);
    nStateSeqBitLeft = numel(stateSeqBits);
    for iIn = 1:k
        if nStateSeqBitLeft == 0
            break;
        else
            if nStateSeqBitLeft >= v(iIn) 
                currStateBits(iIn, 1:v(iIn)) = fliplr(stateSeqBits(1:v(iIn)));
                stateSeqBits = circshift(stateSeqBits, -v(iIn));
                nStateSeqBitLeft = nStateSeqBitLeft - v(iIn);
            else
                currStateBits(iIn, v(iIn)-nStateSeqBitLeft+1:v(iIn)) = fliplr(stateSeqBits(1:nStateSeqBitLeft));
                nStateSeqBitLeft = 0;
            end
        end
    end
    % Shifted out bits
    shiftOutBits = zeros(k, 1);
    for iIn = 1:k
        shiftOutBits(iIn) = currStateBits(iIn, v(iIn));
    end
    idxShiftOut = bi2de(shiftOutBits) + 1;
    % Next state
    nextStateBits(:, 2:m+1) = currStateBits;
    for iStateIn = 1:2^k
        nextStateBitsTmp = nextStateBits;
        inBits = zeros(k, 1);
        inBitsTmp = de2bi(iStateIn-1, 'left-msb').';
        inBits(end-numel(inBitsTmp)+1:end) = inBitsTmp;
        nextStateSeqBits = [];
        for iIn = k:-1:1
            nextStateBitsTmp(iIn, 1) = inBits(iIn);
            nextStateSeqBits = [nextStateSeqBits, nextStateBitsTmp(iIn, 1:v(iIn))];
        end
        nextState = bi2de(nextStateSeqBits, 'left-msb');
        nextStateLut(iState, iStateIn) = nextState; % Left-MSB state
        % Next output
        outBits = zeros(n, 1);
        for idxOut = 1:n
            for iIn = 1:k
                outBits(idxOut) = mod(outBits(idxOut) + sum(nextStateBitsTmp(iIn, 1:m+1).*genPolyBin((idxOut-1)*k+iIn, :)), 2);
            end
        end
        output = bi2de(outBits.', 'left-msb'); % Left-MSB output
        outputLut(iState, iStateIn) = output;
        % Previous state and output
        iNextState = nextState + 1;
        prevStateLut(iNextState, idxShiftOut) = state;
        prevOutputLut(iNextState, idxShiftOut) = output;
    end
    if dbgEn
        fprintf('Next state  at state %d    : %s\n', state, sprintf('%3d, ', nextStateLut(iState, :)));
        fprintf('Next output at state %d    : %s\n', state, sprintf('%3d, ', outputLut(iState, :)));
    end
end

stateInBitLut = zeros(nState, 1);
stateOutBitLut = zeros(nState, 1);
stateInBit = zeros(k, 1);
stateOutBit = zeros(k, 1);
for iState = 1:nState
    state = iState - 1;
    for iIn = 1:k
        stateInBit(iIn) = bitget(state, v(iIn));
        stateOutBit(iIn) = bitget(state, 1);
        state = bitshift(state, v(iIn));
    end
    stateInBitLut(iState) = bi2de(stateInBit, 'left-msb');
    stateOutBitLut(iState) = bi2de(stateOutBit, 'left-msb');
end

%%%% Results
if dbgEn
    fprintf('## Encoding info\n');
    fprintf('Next state:\n');
    for iState = 1:nState
        fprintf('%s\n', sprintf('%3d, ', nextStateLut(iState, :)));
    end
    fprintf('Output:\n');
    for iState = 1:nState
        fprintf('%s\n', sprintf('%3d, ', outputLut(iState, :)));
    end
    fprintf('## Decoding info\n');
    fprintf('Prev state:\n');
    for iState = 1:nState
        fprintf('%s\n', sprintf('%3d, ', prevStateLut(iState, :)));
    end
    fprintf('Prev output:\n');
    for iState = 1:nState
        fprintf('%s\n', sprintf('%3d, ', prevOutputLut(iState, :)));
    end
    fprintf('State input bits:\n');
    for iState = 1:nState
        fprintf('%s\n', sprintf('%3d, ', stateInBitLut(iState, :)));
    end
    fprintf('State output bits:\n');
    for iState = 1:nState
        fprintf('%s\n', sprintf('%3d, ', stateOutBitLut(iState, :)));
    end
end
