function h = figSizeAdj(h, scale)
%Adjust figure size

pos = get(h,'OuterPosition');
set(h, 'OuterPosition', [pos(1), pos(2), scale*pos(3), scale*pos(4)])
