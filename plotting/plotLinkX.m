function h = plotLinkX(varargin)
%Plot input signals on subplots from top to bottom and link x-axis.
%   In each subplot, options should be included in a cell and are shown below.
%     {'x', numeric array, 'y', numeric array, 'leg_str', string, 'y_str', string, 'marker_en', numeric, 'style_str', cell}
%   Other options are shown below.
%     {{subplot1}, {subplot2}, ..., 'title_str', string, 'x_str', string, 'x_min', numeric, 'x_max', numeric}

%%%% Plot style options
colorPat = {'b', 'r', 'g', 'm', 'c', 'k'};
markerPat = {'o', '*' , 's', 'x', '^', 'd'};

%% Extract number of subplots
nPlot = 0;
for iPlotInfo = 1:nargin
    plotInfo = varargin{iPlotInfo};
    if iscell(plotInfo)
        nPlot = nPlot + 1;
    end
end

%% Plot
%%%% Plot style configurations
styleCnt = 1;
markerShift = 0;
styleRot = numel(colorPat);

%%%% Subplot margin configurations
mu = 0.1; height = 0.9; blank = 0.1;

%%%% Main plot
keyword_argin_plot = {};
iPlot = 0;
figure;
h = gobjects(nPlot,1);
for iPlotInfo = 1:nargin
    plotInfo = varargin{iPlotInfo};
    if iscell(plotInfo)
        % Input is cell containing plot information
        iPlot = iPlot + 1;
        h(iPlot) = subplot(nPlot,1,iPlot);
        if iscell(plotInfo{1})
            %% Multiple curves
            % Use embedded plot mode
            plotOverlap(plotInfo{:}, 'mode', 1);
            
        else
            %% Single curve
            keyword_argin = plotInfo;

            %%%% Map keyword arguments
            kKeywordArgNames = {'x', 'y', 'leg_str', 'y_str', 'marker_en', 'style_str'};
            x = [];
            y = [];
            leg_str = '';
            y_str = '';
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
            if ~iscell(style_str)
                error('ERROR! style_str is not cell');
            end
            %%%% Overlapped plot
            if (~isempty(y)) && iscell(y) && (numel(y) > 1)
                if isempty(y_str)
                    plotOverlap({'x', x, 'y', y, 'leg_str', leg_str, 'marker_en', marker_en, 'style_str', style_str}, 'mode', 1);
                else
                    error('ERROR! y_str is NOT empty for overlapped plotting.');
                end
            else
                %%%% Apply keyword arguments
                % Map plot styles
                if isempty(style_str)
                    if (styleCnt > styleRot)
                        styleCnt = 1;
                        markerShift = mod(markerShift+1, styleRot);
                    end
                    if marker_en
                        style_str = {strcat('-', colorPat{styleCnt}, markerPat{mod(styleCnt+markerShift-1, styleRot)+1})};
                    else
                        style_str = {strcat('-', colorPat{styleCnt})};
                    end
                    styleCnt = styleCnt+1;    
                end

                %%%% Main plot
                if ~isempty(y)
                    if ~isempty(x)
                        plot(x, y, style_str{:});
                    else
                        plot(y, style_str{:});
                    end
                else
                    error('ERROR! y is empty.');
                end
                if ~isempty(leg_str)
                    lgdTxt = legend(leg_str);
                    set(lgdTxt, 'interpreter', 'none');
                end
                % Check boolean
                if numel(y) == (sum(y==0)+sum(y==1))
                    ylim([-0.2,1.2]);
                end
                if ~isempty(y_str)
                    ylabel(y_str);
                end            
                grid on;
            end
        end
        posSubplot = get(gca,'pos');
        posSubplot(2) = 1-blank/2-iPlot/nPlot*(1-blank)*height;
        posSubplot(4) = (1-mu)/nPlot*(1-blank)*height; 
        set(gca, 'pos', posSubplot);
        
        % Adjust plot position
        if (iPlot ~= nPlot)
           set(gca, 'XTickLabel', [],'XTick',[]);
        end
    else
        % Add to keyword arguments
        keyword_argin_plot{end+1} = plotInfo;
    end    
end


%% Map top-level keyword arguments
keyword_argin = keyword_argin_plot;
kKeywordArgNames = {'title_str', 'x_str', 'x_min', 'x_max', 'size_scale', 'plot_file_str', 'save_plot_en'};
title_str = '';
x_str = '';
x_min = [];
x_max = [];
size_scale = 1;
plot_file_str = 'plot_linkx';
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


%% Apply keyword arguments
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


%% Link
linkaxes(h(1:iPlot),'x');
zoom on;

if ~isempty(x_min) && ~isempty(x_max)
    xlim(h(end), [x_min, x_max]);
end

%% Adjust size
if size_scale ~= 1
    figSizeAdj(gcf, size_scale);
end

if save_plot_en
    saveas(h, sprintf('%s.png', plot_file_str));
    saveas(h, sprintf('%s.fig', plot_file_str));
end
