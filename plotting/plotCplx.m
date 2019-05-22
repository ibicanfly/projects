function h = plotCplx(varargin)
%Plot real/complex signal array. Options are shown below.
%   {'x', numeric array, 'y', numeric array, 'title_str', string, 'x_str', string, ...
%     'style_str', cell, 'marker_en', numeric, 'mode', 'i, q, mag, ph, iq, magph, iqm, all', ...
%     'mag_mode', 'lin / db', 'x_min', numeric, 'x_max', numeric}

keyword_argin = varargin;

%%%% Map keyword arguments
kKeywordArgNames = {'x', 'y', 'title_str', 'x_str', 'y_str', 'style_str', 'marker_en', 'mode', 'mag_mode', ...
    'x_min', 'x_max', 'size_scale', 'plot_file_str', 'save_plot_en'};
x = [];
y = [];
title_str = '';
x_str = '';
y_str = '';
marker_en = 0;
mag_mode = 'lin'; % lin, db
mode = 'all'; % i, q, mag, ph, iq, magph, iqm, all
x_min = [];
x_max = [];
size_scale = 1;
plot_file_str = 'plot_cplx';
save_plot_en = 0;

% Parse varargin to keyword arguments
if mod(numel(keyword_argin), 2) ~= 0
    error('ERROR! Invalid number of arguments.');
else
    n_keyword_argin = numel(keyword_argin)/2;
end
for i_keyword_argin = 1:n_keyword_argin
    i_keyword = 2*i_keyword_argin-1;
    keyword_found = kKeywordArgNames{strcmp(kKeywordArgNames, keyword_argin{i_keyword})};
    if ~isempty(keyword_found)
        eval(sprintf('%s = keyword_argin{i_keyword+1};', keyword_found));
    else
        fprintf('Argument [%s] is NOT found in keyword list!\n', keyword_argin{i_keyword});
    end
end


%% Main plot
if ~isempty(y)
    if isreal(y)
        % Real signal array
        if marker_en
            h = plotLinkX({'x', x, 'y', y, 'style_str', {'-o'}, 'y_str', y_str}, 'title_str', title_str, 'x_str', x_str, 'x_min', x_min, 'x_max', x_max);
        else
            h = plotLinkX({'x', x, 'y', y, 'y_str', y_str}, 'title_str', title_str, 'x_str', x_str, 'x_min', x_min, 'x_max', x_max);
        end
    else
        % Complex signal array
        re = real(y);
        im = imag(y);
        mag = abs(y);
        magLog = 20*log10(abs(y));
        ph = angle(double(y))/pi*180;
        switch mag_mode
            case 'lin'
                magPlot = mag;
                magYlabel = '';
            case 'db'
                magPlot = magLog;
                magYlabel = 'dB';
            otherwise
                error('ERROR! Invalid mag_mode %s.', mag_mode);
        end
        if marker_en
            i_cell = {'x', x, 'y', re, 'leg_str', 'Real', 'style_str', {'-o'}}; 
            q_cell = {'x', x, 'y', im, 'leg_str', 'Imag', 'style_str', {'-r*'}};
            mag_cell = {'x', x, 'y', magPlot, 'leg_str', 'Mag', 'style_str', {'-g^'}, 'y_str', magYlabel};
            ph_cell = {'x', x, 'y', ph, 'leg_str', 'Phase', 'style_str', {'-cs'}, 'y_str', 'Degree'};
        else
            i_cell = {'x', x, 'y', re, 'leg_str', 'Real', 'style_str', {'-'}};
            q_cell = {'x', x, 'y', im, 'leg_str', 'Imag', 'style_str', {'-'}};
            mag_cell = {'x', x, 'y', magPlot, 'leg_str', 'Mag', 'style_str', {'-'}, 'y_str', magYlabel};
            ph_cell = {'x', x, 'y', ph, 'leg_str', 'Phase', 'style_str', {'-'}, 'y_str', 'Degree'};
        end
        plot_cell = {'title_str', title_str, 'x_str', x_str, 'x_min', x_min, 'x_max', x_max};            
        switch mode
            case 'i'
                plot_ca = {i_cell, plot_cell{:}};
            case 'q'
                plot_ca = {q_cell, plot_cell{:}};
            case 'mag'
                plot_ca = {mag_cell, plot_cell{:}};
            case 'ph'
                plot_ca = {ph_cell, plot_cell{:}};
            case 'iq'
                plot_ca = {i_cell, q_cell, plot_cell{:}};
            case 'magph'
                plot_ca = {mag_cell, ph_cell, plot_cell{:}};
            case 'iqm'
                plot_ca = {i_cell, q_cell, mag_cell, plot_cell{:}};
            case 'all'
                plot_ca = {i_cell, q_cell, mag_cell, ph_cell, plot_cell{:}};
            otherwise
                error('ERROR! Invalid mode %s.', mode);
        end
        h = plotLinkX(plot_ca{:});
    end
    
    % Adjust size
    if size_scale ~= 1
        figSizeAdj(gcf, size_scale);
    end
    
    if save_plot_en
        saveas(h, sprintf('%s.png', plot_file_str));
        saveas(h, sprintf('%s.fig', plot_file_str));
    end
else
    fprintf('Warining! Nothing to plot. Empty data.\n');
end
