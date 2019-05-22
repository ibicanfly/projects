clear;
errShowEn = 1;
dbgEn = 0;
initStateZeroEn = 1;
randSeed = 1;
rng(randSeed);

nbits = 20;
% nbits = 5;
useTermination = 0;
% nbits = 1024;
EbN0 = [0:7];

poly = [[1 1 1]; [1 0 1]];
symIdx = genViterbiTrans(poly);

PER = zeros(1, length(EbN0));
BER = zeros(1, length(EbN0));

numFrames = 10000;
for idx = 1:length(EbN0)
    fprintf('#### EbN0: %.2f\n', EbN0(idx));
    for idxFrame = 1:numFrames
        data = randi(2, 1, nbits) -1;
        
        if(useTermination)
            data = [data, 0, 0]; % termination
        end
        %% encoding
        bit0 = xor(xor(data,  [0, data(1:end-1)]), [0, 0, data(1:end-2)]);
        bit1 = xor(data,  [0, 0, data(1:end-2)]);

        encoded(1:2:length(bit0)*2) = bit0;
        encoded(2:2:length(bit0)*2) = bit1;

        % encoded
        % encodedRef = convenc(data,poly2trellis(3, [7, 5]))


        % modulation and add noise
        modulated = 1-2*encoded;
        received = modulated + 10.^(-(EbN0(idx))/20) * randn(1, length(modulated));
%         received = modulated + 10.^(-(EbN0(idx))/20)*sqrt(2) * randn(1, length(modulated));

        %% decoding
        numStates = 4;
        % find most likely symbol for each state
        prevStateIdx = zeros(numStates, length(received)); % 4 different states
        accum = zeros(numStates, 1); % accumulated likelyhood for all 4 states
        if initStateZeroEn
            accum(2:end) = -inf;
        end

        deSpreaded(1,:) = received(1:2:end) + received(2:2:end);
        deSpreaded(2,:) = received(1:2:end) - received(2:2:end);
        deSpreaded(3,:) = -received(1:2:end) + received(2:2:end);
        deSpreaded(4,:) = -received(1:2:end) - received(2:2:end);

        % generate state transition matrix for viterbi decoder
        for i = 1:length(deSpreaded)          
            accumNew = zeros(size(accum));
            for stateIdx = 1:numStates
                state = stateIdx-1;
                symIdx0 = symIdx(stateIdx, 1); % encoded symbol index if last state bit was a '0'
                symIdx1 = symIdx(stateIdx, 2); % encoded symbol index if last state bit was a '1'

                prevStateIdx0 = mod(bitshift(state, 1),numStates) +1;
                prevStateIdx1 = prevStateIdx0 + 1;

                % likelyhood for path 0
                path0 = accum(prevStateIdx0) + deSpreaded(symIdx0, i);
                % likelyhood for path 1
                path1 = accum(prevStateIdx1) + deSpreaded(symIdx1, i);
                if dbgEn
                    fprintf('path0, path1   : %.2f, %.2f\n', path0, path1);
                end
                if path0 > path1                    
                    accumNew(stateIdx) = path0;
                    prevStateIdx(stateIdx, i) = prevStateIdx0;
                else
                    accumNew(stateIdx) = path1;
                    prevStateIdx(stateIdx, i) = prevStateIdx1;
                end
            end
            
            accum = accumNew;
            if dbgEn
                fprintf('PrevStateIdx   : %s\n', sprintf('%d, ', prevStateIdx(:, i)));
                fprintf('MetricAcc      : %s\n', sprintf('%d, ', accumNew));
            end
        end

        % trace back most likely path
        if(useTermination)
            lastStateIdx = 1;
        else
            [~, lastStateIdx] = max(accum);
        end
        for i = length(deSpreaded) :-1:1
            if dbgEn
                fprintf('lastStateIdx   : %d\n', lastStateIdx);
            end
            decoded(i) = bitget(lastStateIdx-1, 3-1);

            lastStateIdx = prevStateIdx(lastStateIdx, i);
        end
        if dbgEn
            fprintf('data           : %s\n', sprintf('%d, ', data));
        end
        if(useTermination)
            if errShowEn
                if ~isequal(decoded(1:end-2),data(1:end-2))
                    fprintf('Frame [%05d]: %s\n', idxFrame, sprintf('%d, ', find(decoded(1:end-2)~=data(1:end-2))));
                end
            end
            PER(idx) = PER(idx) + (isequal(decoded(1:end-2),data(1:end-2)) == 0);
            BER(idx) = BER(idx) + sum(decoded(1:end-2) ~= data(1:end-2));
        else
            if errShowEn
                if ~isequal(decoded,data)
                    fprintf('Frame [%05d]: %s\n', idxFrame, sprintf('%d, ', find(decoded~=data)));
                end
            end
            PER(idx) = PER(idx) + (isequal(decoded,data) == 0);
            BER(idx) = BER(idx) + sum(decoded ~= data);
        end
    end
end

figure;
% hold on;
semilogy(EbN0, PER / numFrames);
title('PER');
grid on;
figure;
semilogy(EbN0, BER / numFrames / nbits);
title('BER');
grid on;
