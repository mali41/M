


CVlist=cell2mat(reshape(A.D(cellfun(@(x)~isempty(x)&&~isnan(x(1)),A.D)),1,1,[]));


imagesc(log10(mean(CVlist,3)));