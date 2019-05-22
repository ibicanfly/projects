function stateTransIdx = genViterbiTrans(viterbiPoly)
    k = size(viterbiPoly, 2); % constraint length
    numStates = 2^(k-1);

    words = 0:(2^k -1); % all possible code words (input to the viterbi encoder
    %wordsBin = de2bi(words, k, 'left-msb').'; % codewords in binary
    wordsBin = mex_de2bi(words.', k, 2, 'left-msb').'; % codewords in binary

    encWordsBin = mod(viterbiPoly * double(wordsBin), 2);
    %encWords = bi2de(encWordsBin.','left-msb');
    encWords = mex_bi2de(uint8(encWordsBin.'),'left-msb');

    stateTransIdx = zeros(numStates, 2); % encoded symbols to reach a specific state index (row = state index, column = last state bit)
    % generate symbol mapping
    %newState = bi2de(wordsBin(1:k-1,:).', 'left-msb');
    newState = mex_bi2de(uint8(wordsBin(1:k-1,:).'), 'left-msb');
    for i = 1:length(newState)
        newStateIdx = newState(i)+1;
        oldBit = wordsBin(k, i);
        encWord = encWords(i);
        stateTransIdx(newStateIdx, oldBit+1) = encWord + 1;% encoded symbol index, if last state bit was equal to 'oldBit'
    end
 end