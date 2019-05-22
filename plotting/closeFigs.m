function closeFigs(idxStart, idxEnd)
%CLOSEFIGS Close figures with index from idxStart to idxEnd

for i = idxStart:idxEnd
    try
        close(i);
    catch
        printf('Closing figure #%d failed!\n', i);
    end
end
