% Convolutional Encoding with Puncturing
convEncoder = comm.ConvolutionalEncoder(poly2trellis(7, [171 133]));
convEncoder.PuncturePatternSource = 'Property';
convEncoder.PuncturePattern = [1;1;0;1;1;0];
bpskMod = comm.BPSKModulator;

% Modulator and Channel
channel = comm.AWGNChannel('NoiseMethod', 'Signal to noise ratio (Eb/No)',...
  'SignalPower', 1, 'SamplesPerSymbol', 1);

% Viterbi Decoding with Depuncturing
vitDecoder = comm.ViterbiDecoder(poly2trellis(7, [171 133]), ...
  'InputFormat', 'Unquantized');
vitDecoder.PuncturePatternSource =  'Property';
vitDecoder.PuncturePattern = convEncoder.PuncturePattern;
vitDecoder.TracebackDepth = 96;

% Calculating the Error Rate
errorCalc = comm.ErrorRate('ReceiveDelay', vitDecoder.TracebackDepth);


EbNoEncoderInput = 2:0.5:5; % in dB
EbNoEncoderOutput = EbNoEncoderInput + 10*log10(3/4);
frameLength = 3000;         % this value must be an integer multiple of 3
targetErrors = 300; 
maxNumTransmissions = 5e6;
BERVec = zeros(3,length(EbNoEncoderOutput)); % Allocate memory to store results
for n=1:length(EbNoEncoderOutput)
    reset(errorCalc)
    reset(convEncoder)
    reset(vitDecoder)
    channel.EbNo = EbNoEncoderOutput(n); % Set the channel EbNo value for simulation
    while (BERVec(2,n) < targetErrors) && (BERVec(3,n) < maxNumTransmissions)  
        % Generate binary frames of size specified by the frameLength variable
        data = randi([0 1], frameLength, 1);
        % Convolutionally encode the data
        encData = convEncoder(data);
        % Modulate the encoded data
        modData = bpskMod(encData);
        % Pass the modulated signal through an AWGN channel
        channelOutput = channel(modData);
        % Pass the real part of the channel complex outputs as the unquantized
        % input to the Viterbi decoder. 
        decData = vitDecoder(real(channelOutput));
        % Compute and accumulate errors
        BERVec(:,n) = errorCalc(data, decData);
    end
end

dist = 5:11;
nerr = [42 201 1492 10469 62935 379644 2253373];
codeRate = 3/4;
bound = nerr*(1/6)*erfc(sqrt(codeRate*(10.0.^((2:.02:5)/10))'*dist))';

berfit(EbNoEncoderInput,BERVec(1,:)); % Curve-fitted simulation results
hold on;
semilogy((2:.02:5),bound,'g'); % Theoretical results
legend('Empirical BER','Fit for simulated BER', 'Theoretical bound on BER')
axis([1 6 10^-5 1])