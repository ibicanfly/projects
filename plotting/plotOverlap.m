function h = plotOverlap(varargin)
%Plot overlapped signals.
%   In each overlapped signal, options should be included in a cell and are shown below.
%     {'x', numeric array, 'y', numeric array, 'leg_str', string, 'marker_en', numeric, 'style_str', cell}
%   Other options are shown below.
%     {{overlap1}, {overlap2}, ..., 'title_str', string, 'x_str', string, 'y_str', string, ...
%       'x_min', numeric, 'x_max', numeric, 'y_min', numeric, 'y_max', numeric, 'mode', numeric}

%%%% Plot style options
colorPat = {'b', 'r', 'g', 'm', 'c', 'k'};
lineStylePat = {'-', '--' , '-.'};
linePat = {};
for i_lineStyle = 1:numel(lineStylePat)
    linePat = [linePat, strcat(colorPat, lineStylePat{i_lineStyle})];
end
markerPat = {'o', '*' , 's', 'x', '^', 'd'};

%% Plot
%%%% Plot style configurations
styleCnt = 1;
markerShift = 0;
styleRot = numel(linePat);

%%%% Main plot
x_ca = {};
y_ca = {};
leg_str_ca = {};
style_str_ca = {};
keyword_argin_plot = {};
iPlot = 0;
for iPlotInfo = 1:nargin
    plotInfo = varargin{iPlotInfo};
    if iscell(plotInfo)
        %% Single curve
        iPlot = iPlot + 1;

        keyword_argin = plotInfo;

        %%%% Map keyword arguments
        kKeywordArgNames = {'x', 'y', 'leg_str', 'marker_en', 'style_str'};
        x = [];
        y = [];
        leg_str = '';
        marker_en = 0;
        style_str = {};

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
        x_ca = [x_ca; x(:)];
        y_ca = [y_ca; y(:)];
        leg_str_ca = [leg_str_ca; leg_str(:)];

        %%%% Apply keyword arguments
        % Map plot styles
        if isempty(style_str)
            if iscell(y)
                n_y = numel(y(:));
            else
                n_y = 1;
            end
            for i_style_str = 1:n_y
                if (styleCnt > styleRot)
                    styleCnt = 1;
                    markerShift = mod(markerShift+1, styleRot);
                end
%                 if marker_en
%                     style_str{end+1} = {strcat(linePat{styleCnt}, markerPat{mod(styleCnt+markerShift-1, styleRot)+1})};
%                 else
%                     style_str{end+1} = {strcat(linePat{styleCnt})};
%                 end
                if marker_en
                    style_str{end+1} = strcat(linePat{styleCnt}, markerPat{mod(styleCnt+markerShift-1, styleRot)+1});
                else
                    style_str{end+1} = strcat(linePat{styleCnt});
                end
                styleCnt = styleCnt+1;
            end
            style_str = style_str';
        end
%         style_str_ca = [style_str_ca; {style_str}];
%         style_str_ca = [style_str_ca; style_str];
        style_str_ca{end+1} = style_str;
    else
        % Add to keyword arguments
        keyword_argin_plot{end+1} = plotInfo;
    end    
end


%% Map top-level keyword arguments
keyword_argin = keyword_argin_plot;
kKeywordArgNames = {'title_str', 'leg_loc', 'x_str', 'y_str', 'x_min', 'x_max', 'y_min', 'y_max', 'size_scale', 'mode', 'plot_file_str', 'save_plot_en'};
title_str = '';
leg_loc = 'northeast';
x_str = '';
y_str = '';
x_min = [];
x_max = [];
y_min = [];
y_max = [];
size_scale = 1;
mode = 0;  % 0: independent plot; 1: embedded plot in plotLinkX
plot_file_str = 'plot_overlap';
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

%% Plot
if mode == 0
    figure;
end
h = gca;
hold all;

% Orig
% nPlot = max([numel(x_ca), numel(y_ca), numel(leg_str_ca), size(style_str_ca, 1)]);
nPlot = max([numel(x_ca), numel(y_ca), numel(leg_str_ca), numel(style_str_ca)]);
if (~isempty(x_ca) && (numel(x_ca) ~= nPlot)) ...
    || (~isempty(y_ca) && (numel(y_ca) ~= nPlot)) ...
    || (~isempty(leg_str_ca) && (numel(leg_str_ca) ~= nPlot)) ...
...% Orig
...%     || (~isempty(style_str_ca) && (size(style_str_ca, 1) ~= nPlot)) 
    || (~isempty(style_str_ca) && (numel(style_str_ca) ~= nPlot)) 
    error('ERROR! Number of data mismatch.');
end
allBoolean = 1;
for iPlot = 1:nPlot
    if ~isempty(y_ca{iPlot})
        if ~isempty(x_ca) && ~isempty(x_ca{iPlot})
% Orig
%             plot(x_ca{iPlot}, y_ca{iPlot}, style_str_ca{iPlot,:});
            plot(x_ca{iPlot}, y_ca{iPlot}, style_str_ca{iPlot}{:});
        else
% Orig
%             plot(y_ca{iPlot}, style_str_ca{iPlot});
            plot(y_ca{iPlot}, style_str_ca{iPlot}{:});
        end
    else
        error('ERROR! y is empty.');
    end
    % Check boolean
    if numel(y_ca{iPlot}) ~= (sum(y_ca{iPlot}==0)+sum(y_ca{iPlot}==1))
        allBoolean = 0;
    end
end
if allBoolean
    ylim([-0.2,1.2]);
end
grid on;
lgdTxt = legend(leg_str_ca);
set(lgdTxt, 'interpreter', 'none', 'Location', leg_loc);

if ~isempty(title_str)
    if ischar(title_str)
        % Title added on h(1)
        titleInfo = get(h(1), 'title');
        titleInfo.String = title_str;
        set(h(1), 'title', titleInfo);
    else
        error('ERROR! Invalid plot element data type.');
    end
end
if ~isempty(x_str)
    if ischar(x_str)
        % Title added on h(end)
        xlabelInfo = get(h(end), 'XLabel');
        xlabelInfo.String = x_str;
        set(h(end), 'XLabel', xlabelInfo);
    else
        error('ERROR! Invalid plot element data type.');
    end
end
if ~isempty(y_str)
    if ischar(y_str)
        % Title added on h(end)
        ylabelInfo = get(h(end), 'YLabel');
        ylabelInfo.String = y_str;
        set(h(end), 'YLabel', ylabelInfo);
    else
        error('ERROR! Invalid plot element data type.');
    end
end
if ~isempty(x_min) && ~isempty(x_max)
    xlim(h, [x_min, x_max]);
end
if ~isempty(y_min) && ~isempty(y_max)
    ylim(h, [y_min, y_max]);
end
zoom on;

%% Adjust size
if size_scale ~= 1
    figSizeAdj(gcf, size_scale);
end

if save_plot_en
    saveas(h, sprintf('%s.png', plot_file_str));
    saveas(h, sprintf('%s.fig', plot_file_str));
end
