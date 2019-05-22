function [decBits] = conv_dec(sigRx, encMode, decRandInitStateEn, nDecSmp, nPathTraceBack, stateInit, k, n, vTot, ...
    bitMapping, prevStateLut, prevOutputLut, stateInBitLut, inBitsRef, dbgEn)

    %     lenTraceBack = 5*vTot;
    nState = 2^vTot;
    pathTraceBack = zeros(nState, nPathTraceBack); % Store input bits only
    if decRandInitStateEn
        metricFinal = zeros(nState, 1);
    else
        metricFinal = -Inf(nState, 1);
        metricFinal(stateInit+1) = 0;
    end
    metricCmp = zeros(2^k, 1);
    iPathTraceBack = 1;

    % Debug
    if dbgEn
        metricFinalTraceBackDbg = zeros(nState, nPathTraceBack);
        prevStateTraceBackDbg = zeros(nState, 2^k, nPathTraceBack);
        metricCmpDbg = zeros(nState, 2^k, nPathTraceBack);
        metricTmpDbg = zeros(nState, 2^k, nPathTraceBack);
        metricTmp = zeros(2^k, 1);
    end
    
    decBits = zeros(nDecSmp*k, 1);
    for iSmp = 1:nDecSmp
        inSoftDec = sigRx((iSmp-1)*n+1:iSmp*n);
        % Compare metric for each state
        prevMetricFinal = metricFinal;
        if dbgEn
            fprintf('# Index [%d]\n', iSmp);
        end
        for iState = 1:nState
            for iPath = 1:2^k
                metricCmp(iPath) = prevMetricFinal(prevStateLut(iState, iPath)+1) + sum(inSoftDec.*bitMapping(prevOutputLut(iState, iPath)+1, :).');
                metricTmp(iPath) = sum(inSoftDec.*bitMapping(prevOutputLut(iState, iPath)+1, :).');
            end
            [metricMax, iPathMax] = max(metricCmp);
            metricFinal(iState) = metricMax;
            pathTraceBack(iState, iPathTraceBack) = iPathMax - 1;
            % Debug
            if dbgEn
                prevStateTraceBackDbg(iState, :, iPathTraceBack) = prevStateLut(iState, :);
                metricTmpDbg(iState, :, iPathTraceBack) = metricTmp;
                metricCmpDbg(iState, :, iPathTraceBack) = metricCmp;
                metricFinalTraceBackDbg(iState, iPathTraceBack) = metricMax;
    %                 for iState = 1:nState
    %                     fprintf('%d / %6.2f\n', iState, prevMetricFinal(iState));
    %                 end
                fprintf('State [%d]\n', iState-1);
                for iPath = 1:2^k
                    fprintf('%d/', prevStateLut(iState, iPath));
                    fprintf('%s/', sprintf('%d,', de2bi(prevOutputLut(iState, iPath), n, 'left-msb')));
                    fprintf('%s/', sprintf('%+d,', bitMapping(prevOutputLut(iState, iPath)+1, :).'));
                    fprintf('%s/', sprintf('%+6.2f,', inSoftDec));
                    fprintf('%+7.2f/', metricTmpDbg(iState, iPath, iPathTraceBack));
                    fprintf('%+7.2f\n', metricCmpDbg(iState, iPath, iPathTraceBack));
                end
                fprintf('Select prev state [%d]\n', prevStateLut(iState, pathTraceBack(iState, iPathTraceBack)+1));
            end
        end
        if dbgEn
            for iState = 1:nState
                fprintf('%d / %7.2f\n', iState-1, metricFinal(iState));
            end
        end

        % Decoding
        if iSmp >= nPathTraceBack
            if (iSmp == nDecSmp)
                if (encMode == 1)
                    % Terminated
                    iStateMax = 1;
                else
                    [~, iStateMax] = max(metricFinal);
                end
            else
                [~, iStateMax] = max(metricFinal);
            end
            % Trace back
            iPathTraceBackTmp = iPathTraceBack;
            iCurrState = iStateMax;
            iDecSmp = iSmp;
            for iTraceBack = 1:nPathTraceBack
    %                     if dbgEn
                if 0
                    for iState = 1:nState
                        fprintf('%d / %6.2f\n', iState, metricFinalTraceBackDbg(iState, iTraceBack));
                    end
                    for iState = 1:nState
                        fprintf('State [%d]\n', iState-1);
                        for iPath = 1:2^k
                            fprintf('%d/,', prevStateLut(iState, iPath));
                            fprintf('%s/', sprintf('%d,', de2bi(prevOutputLut(iState, iPath), n, 'left-msb')));
                            fprintf('%s/', sprintf('%d,', bitMapping(prevOutputLut(iState, iPath)+1, :).'));
                            fprintf('%s/', sprintf('%.2f,', inSoftDec));
                            fprintf('%.2f\n', metricDbg(iState, iPath, iTraceBack));
                        end
                    end
                    for iState = 1:nState
                        fprintf('%d / %6.2f\n', iState-1, metricFinalTraceBackDbg(iState, iTraceBack));
                    end
                end
                if (iSmp == nDecSmp) || (iTraceBack == nPathTraceBack)
    %                         decSmpBits = de2bi(pathTraceBack(currState+1, iPathTraceBackTmp), 'left-msb');
                    decBits((iDecSmp-1)*k+1:iDecSmp*k) = stateInBitLut(iCurrState);
                    if dbgEn
                        fprintf('# Index [%d]\n', iDecSmp);
                        fprintf('Decoded bits   : %s\n', sprintf('%d, ', decBits((iDecSmp-1)*k+1:iDecSmp*k)));
                        fprintf('Input bits     : %s\n', sprintf('%d, ', inBitsRef((iDecSmp-1)*k+1:iDecSmp*k)));
                    end
                end
                iDecSmp = iDecSmp - 1;
                prevState = prevStateLut(iCurrState, pathTraceBack(iCurrState, iPathTraceBackTmp)+1);
                if dbgEn
                    fprintf('Prev state     : %d\n', prevState);
                end
                iCurrState = prevState + 1;
                iPathTraceBackTmp = iPathTraceBackTmp - 1;
                % No comparison required for nTraceBack with power of 2
                if iPathTraceBackTmp < 1
                    iPathTraceBackTmp = iPathTraceBackTmp + nPathTraceBack;
                end
            end

        end
        iPathTraceBack = iPathTraceBack + 1;
        % No comparison required for nTraceBack with power of 2
        if iPathTraceBack > nPathTraceBack
            iPathTraceBack = iPathTraceBack - nPathTraceBack;
        end
    end
end