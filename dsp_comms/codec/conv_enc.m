function [encBits] = conv_enc(inBits, nEncSmp, stateInit, k, n, nextStateLut, outputLut)
    outputDec = zeros(nEncSmp, 1);
    currState = stateInit;
    % Serial processing to accelerate bi2de
    idxInBits = bi2de(reshape(inBits, k, []).', 'left-msb') + 1;
    for iSmp = 1:nEncSmp
%         inBit = bi2de(inBits((iSmp-1)*k+1:iSmp*k).', 'left-msb');
        iCurrState = currState + 1;
        nextState = nextStateLut(iCurrState, idxInBits(iSmp));
        outputDec(iSmp) = outputLut(iCurrState, idxInBits(iSmp));
        currState = nextState;
    end
    % Serial processing to accelerate de2bi
    encBits = reshape(de2bi(outputDec, n, 2, 'left-msb').', 1, []).';
end