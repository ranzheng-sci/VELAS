function outdata = json2struct(indata)

%{
   This code is copied from Qianqian Fang's and plotly's loadjson, MANY THANKS to them!
   
   Source: [1] http://iso2mesh.sourceforge.net/cgi-bin/index.cgi?jsonlab
           [2] https://github.com/fangq/jsonlab
           [3] https://github.com/plotly/plotly_matlab

    Copyright (c) 2011-2020 Qianqian Fang <q.fang at neu.edu>
    Copyright (c) 2014,2016 Bastian Bechtold
    Copyright (c) 2012, Kota Yamaguchi
    Copyright (c) 2009, Nedialko Krouchev
    Copyright (c) 2009, Fran鏾is Glineur
    Copyright (c) 2008, Joel Feenstra
    
    All rights reserved.
                              <LICENSE_BSD>
    Redistribution and use in source and binary forms, with or without modification, 
    are permitted provided that the following conditions are met:
    
    * Redistributions of source code must retain the above copyright notice, this 
      list of conditions and the following disclaimer.
    
    * Redistributions in binary form must reproduce the above copyright notice, 
      this list of conditions and the following disclaimer in the documentation 
      and/or other materials provided with the distribution.
    
    * Neither the name of the copyright holder nor the names of its contributors 
      may be used to endorse or promote products derived from this software without 
      specific prior written permission.
    
    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


%}

global pos inStr len esc index_esc len_esc isoct arraytoken

warning off;
pos   = 1; 
len   = length(indata); 
inStr = indata;
isoct = exist('OCTAVE_VERSION');
arraytoken=find(inStr=='[' | inStr==']' | inStr=='"');
jstr=regexprep(inStr,'\\\\','  ');
escquote=regexp(jstr,'\\"');
arraytoken=sort([arraytoken escquote]);
% String delimiters and escape chars identified to improve speed:
esc = find(inStr=='"' | inStr=='\' ); % comparable to: regexp(inStr, '["\\]');
index_esc = 1; len_esc = length(esc);
opt=struct;
jsoncount=1;

while pos <= len
    switch(next_char)
        case '{'
            outdata{jsoncount} = parse_object(opt);
        case '['
            outdata{jsoncount} = parse_array(opt);
        otherwise
            error_pos('Outer level structure must be an object or an array');
    end
    jsoncount=jsoncount+1;
end % while
jsoncount=length(outdata);
if(jsoncount==1 && iscell(outdata))
    outdata=outdata{1};
end
if(~isempty(outdata))
    if(isstruct(outdata)) % data can be a struct array
        outdata=jstruct2array(outdata);
    elseif(iscell(outdata))
        outdata=jcell2array(outdata);
    end
end
%%
function newdata=parse_collection(id,data,obj)
if(jsoncount>0 && exist('data','var'))
    if(~iscell(data))
        newdata=cell(1);
        newdata{1}=data;
        data=newdata;
    end
end
%%
function newdata=jcell2array(data)
len=length(data);
newdata=data;
for i=1:len
    if(isstruct(data{i}))
        newdata{i}=jstruct2array(data{i});
    elseif(iscell(data{i}))
        newdata{i}=jcell2array(data{i});
    end
end
%%-------------------------------------------------------------------------
function newdata=jstruct2array(data)
fn=fieldnames(data);
newdata=data;
len=length(data);
for i=1:length(fn) % depth-first
    for j=1:len
        if(isstruct(getfield(data(j),fn{i})))
            newdata(j)=setfield(newdata(j),fn{i},jstruct2array(getfield(data(j),fn{i})));
        end
    end
end
if(~isempty(strmatch('x0x5F_ArrayType_',fn)) && ~isempty(strmatch('x0x5F_ArrayData_',fn)))
    newdata=cell(len,1);
    for j=1:len
        ndata=cast(data(j).x0x5F_ArrayData_,data(j).x0x5F_ArrayType_);
        iscpx=0;
        if(~isempty(strmatch('x0x5F_ArrayIsComplex_',fn)))
            if(data(j).x0x5F_ArrayIsComplex_)
                iscpx=1;
            end
        end
        if(~isempty(strmatch('x0x5F_ArrayIsSparse_',fn)))
            if(data(j).x0x5F_ArrayIsSparse_)
                if(~isempty(strmatch('x0x5F_ArraySize_',fn)))
                    dim=data(j).x0x5F_ArraySize_;
                    if(iscpx && size(ndata,2)==4-any(dim==1))
                        ndata(:,end-1)=complex(ndata(:,end-1),ndata(:,end));
                    end
                    if isempty(ndata)
                        % All-zeros sparse
                        ndata=sparse(dim(1),prod(dim(2:end)));
                    elseif dim(1)==1
                        % Sparse row vector
                        ndata=sparse(1,ndata(:,1),ndata(:,2),dim(1),prod(dim(2:end)));
                    elseif dim(2)==1
                        % Sparse column vector
                        ndata=sparse(ndata(:,1),1,ndata(:,2),dim(1),prod(dim(2:end)));
                    else
                        % Generic sparse array.
                        ndata=sparse(ndata(:,1),ndata(:,2),ndata(:,3),dim(1),prod(dim(2:end)));
                    end
                else
                    if(iscpx && size(ndata,2)==4)
                        ndata(:,3)=complex(ndata(:,3),ndata(:,4));
                    end
                    ndata=sparse(ndata(:,1),ndata(:,2),ndata(:,3));
                end
            end
        elseif(~isempty(strmatch('x0x5F_ArraySize_',fn)))
            if(iscpx && size(ndata,2)==2)
                ndata=complex(ndata(:,1),ndata(:,2));
            end
            ndata=reshape(ndata(:),data(j).x0x5F_ArraySize_);
        end
        newdata{j}=ndata;
    end
    if(len==1)
        newdata=newdata{1};
    end
end
%%-------------------------------------------------------------------------
function object = parse_object(varargin)
parse_char('{');
object = [];
if next_char ~= '}'
    while 1
        str = parseStr(varargin{:});
        if isempty(str)
            error_pos('Name of value at position %d cannot be empty');
        end
        parse_char(':');
        val = parse_value(varargin{:});
        eval( sprintf( 'object.%s  = val;', valid_field(str) ) );
        if next_char == '}'
            break;
        end
        parse_char(',');
    end
end
parse_char('}');
%%-------------------------------------------------------------------------
function object = parse_array(varargin) % JSON array is written in row-major order
global pos inStr isoct
parse_char('[');
object = cell(0, 1);
dim2=[];
if next_char ~= ']'
    [endpos e1l e1r maxlevel]=matching_bracket(inStr,pos);
    arraystr=['[' inStr(pos:endpos)];
    arraystr=regexprep(arraystr,'"_NaN_"','NaN');
    arraystr=regexprep(arraystr,'"([-+]*)_Inf_"','$1Inf');
    arraystr(find(arraystr==sprintf('\n')))=[];
    arraystr(find(arraystr==sprintf('\r')))=[];
    %arraystr=regexprep(arraystr,'\s*,',','); % this is slow,sometimes needed
    if(~isempty(e1l) && ~isempty(e1r)) % the array is in 2D or higher D
        astr=inStr((e1l+1):(e1r-1));
        astr=regexprep(astr,'"_NaN_"','NaN');
        astr=regexprep(astr,'"([-+]*)_Inf_"','$1Inf');
        astr(find(astr==sprintf('\n')))=[];
        astr(find(astr==sprintf('\r')))=[];
        astr(find(astr==' '))='';
        if(isempty(find(astr=='[', 1))) % array is 2D
            dim2=length(sscanf(astr,'%f,',[1 inf]));
        end
    else % array is 1D
        astr=arraystr(2:end-1);
        astr(find(astr==' '))='';
        [obj count errmsg nextidx]=sscanf(astr,'%f,',[1,inf]);
        if(nextidx>=length(astr)-1)
            object=obj;
            pos=endpos;
            parse_char(']');
            return;
        end
    end
    if(~isempty(dim2))
        astr=arraystr;
        astr(find(astr=='['))='';
        astr(find(astr==']'))='';
        astr(find(astr==' '))='';
        [obj count errmsg nextidx]=sscanf(astr,'%f,',inf);
        if(nextidx>=length(astr)-1)
            object=reshape(obj,dim2,numel(obj)/dim2)';
            pos=endpos;
            parse_char(']');
            return;
        end
    end
    arraystr=regexprep(arraystr,'\]\s*,','];');
    try
        if(isoct && regexp(arraystr,'"','once'))
            error('Octave eval can produce empty cells for JSON-like input');
        end
        object=eval(arraystr);
        pos=endpos;
    catch
        while 1
            val = parse_value(varargin{:});
            object{end+1} = val;
            if next_char == ']'
                break;
            end
            parse_char(',');
        end
    end
end
if(jsonopt('SimplifyCell',0,varargin{:})==1)
    try
        oldobj=object;
        object=cell2mat(object')';
        if(iscell(oldobj) && isstruct(object) && numel(object)>1 && jsonopt('SimplifyCellArray',1,varargin{:})==0)
            object=oldobj;
        elseif(size(object,1)>1 && ndims(object)==2)
            object=object';
        end
    catch
    end
end
parse_char(']');
%%-------------------------------------------------------------------------
function parse_char(c)
global pos inStr len
skip_whitespace;
if pos > len || inStr(pos) ~= c
    error_pos(sprintf('Expected %c at position %%d', c));
else
    pos = pos + 1;
    skip_whitespace;
end
%%-------------------------------------------------------------------------
function c = next_char
global pos inStr len
skip_whitespace;
if pos > len
    c = [];
else
    c = inStr(pos);
end
%%-------------------------------------------------------------------------
function skip_whitespace
global pos inStr len
while pos <= len && isspace(inStr(pos))
    pos = pos + 1;
end
%%-------------------------------------------------------------------------
function str = parseStr(varargin)
global pos inStr len  esc index_esc len_esc
% len, ns = length(inStr), keyboard
if inStr(pos) ~= '"'
    error_pos('String starting with " expected at position %d');
else
    pos = pos + 1;
end
str = '';
while pos <= len
    while index_esc <= len_esc && esc(index_esc) < pos
        index_esc = index_esc + 1;
    end
    if index_esc > len_esc
        str = [str inStr(pos:len)];
        pos = len + 1;
        break;
    else
        str = [str inStr(pos:esc(index_esc)-1)];
        pos = esc(index_esc);
    end
    nstr = length(str); switch inStr(pos)
        case '"'
            pos = pos + 1;
            if(~isempty(str))
                if(strcmp(str,'_Inf_'))
                    str=Inf;
                elseif(strcmp(str,'-_Inf_'))
                    str=-Inf;
                elseif(strcmp(str,'_NaN_'))
                    str=NaN;
                end
            end
            return;
        case '\'
            if pos+1 > len
                error_pos('End of file reached right after escape character');
            end
            pos = pos + 1;
            switch inStr(pos)
                case {'"' '\' '/'}
                    str(nstr+1) = inStr(pos);
                    pos = pos + 1;
                case {'b' 'f' 'n' 'r' 't'}
                    str(nstr+1) = sprintf(['\' inStr(pos)]);
                    pos = pos + 1;
                case 'u'
                    if pos+4 > len
                        error_pos('End of file reached in escaped unicode character');
                    end
                    str(nstr+(1:6)) = inStr(pos-1:pos+4);
                    pos = pos + 5;
            end
        otherwise % should never happen
            str(nstr+1) = inStr(pos), keyboard
            pos = pos + 1;
    end
end
error_pos('End of file while expecting end of inStr');
%%-------------------------------------------------------------------------
function num = parse_number(varargin)
global pos inStr len isoct
currstr=inStr(pos:end);
numstr=0;
if(isoct~=0)
    numstr=regexp(currstr,'^\s*-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+\-]?\d+)?','end');
    [num, one] = sscanf(currstr, '%f', 1);
    delta=numstr+1;
else
    [num, one, err, delta] = sscanf(currstr, '%f', 1);
    if ~isempty(err)
        error_pos('Error reading number at position %d');
    end
end
pos = pos + delta-1;
%%-------------------------------------------------------------------------
function val = parse_value(varargin)
global pos inStr len
% true = 1; false = 0;
switch(inStr(pos))
    case '"'
        val = parseStr(varargin{:});
        return;
    case '['
        val = parse_array(varargin{:});
        return;
    case '{'
        val = parse_object(varargin{:});
        if isstruct(val)
            if(~isempty(strmatch('x0x5F_ArrayType_',fieldnames(val), 'exact')))
                val=jstruct2array(val);
            end
        elseif isempty(val)
            val = struct;
        end
        return;
    case {'-','0','1','2','3','4','5','6','7','8','9'}
        val = parse_number(varargin{:});
        return;
    case 't'
        if pos+3 <= len && strcmpi(inStr(pos:pos+3), 'true')
            val = true;
            pos = pos + 4;
            return;
        end
    case 'f'
        if pos+4 <= len && strcmpi(inStr(pos:pos+4), 'false')
            val = false;
            pos = pos + 5;
            return;
        end
    case 'n'
        if pos+3 <= len && strcmpi(inStr(pos:pos+3), 'null')
            val = NaN;
            pos = pos + 4;
            return;
        end
end
error_pos('Value expected at position %d');
%%-------------------------------------------------------------------------
function error_pos(msg)
global pos inStr len
poShow = max(min([pos-15 pos-1 pos pos+20],len),1);
if poShow(3) == poShow(2)
    poShow(3:4) = poShow(2)+[0 -1];  % display nothing after
end
msg = [sprintf(msg, pos) ': ' ...
    inStr(poShow(1):poShow(2)) '<error>' inStr(poShow(3):poShow(4)) ];
error( ['JSONparser:invalidFormat: ' msg] );
%%-------------------------------------------------------------------------
function str = valid_field(str)
global isoct
% From MATLAB doc: field names must begin with a letter, which may be
% followed by any combination of letters, digits, and underscores.
% Invalid characters will be converted to underscores, and the prefix
% "x0x[Hex code]_" will be added if the first character is not a letter.
pos=regexp(str,'^[^A-Za-z]','once');
if(~isempty(pos))
    if(~isoct)
        str=regexprep(str,'^([^A-Za-z])','x0x${sprintf(''%X'',unicode2native($1))}_','once');
    else
        str=sprintf('x0x%X_%s',char(str(1)),str(2:end));
    end
end
if(isempty(regexp(str,'[^0-9A-Za-z_]', 'once' ))) return;  end
if(~isoct)
    str=regexprep(str,'([^0-9A-Za-z_])','_0x${sprintf(''%X'',unicode2native($1))}_');
else
    pos=regexp(str,'[^0-9A-Za-z_]');
    if(isempty(pos)) return; end
    str0=str;
    pos0=[0 pos(:)' length(str)];
    str='';
    for i=1:length(pos)
        str=[str str0(pos0(i)+1:pos(i)-1) sprintf('_0x%X_',str0(pos(i)))];
    end
    if(pos(end)~=length(str))
        str=[str str0(pos0(end-1)+1:pos0(end))];
    end
end
%str(~isletter(str) & ~('0' <= str & str <= '9')) = '_';
%%-------------------------------------------------------------------------
function endpos = matching_quote(str,pos)
len=length(str);
while(pos<len)
    if(str(pos)=='"')
        if(~(pos>1 && str(pos-1)=='\'))
            endpos=pos;
            return;
        end
    end
    pos=pos+1;
end
error('unmatched quotation mark');
%%-------------------------------------------------------------------------
function [endpos e1l e1r maxlevel] = matching_bracket(str,pos)
global arraytoken
level=1;
maxlevel=level;
endpos=0;
bpos=arraytoken(arraytoken>=pos);
tokens=str(bpos);
len=length(tokens);
pos=1;
e1l=[];
e1r=[];
while(pos<=len)
    c=tokens(pos);
    if(c==']')
        level=level-1;
        if(isempty(e1r)) e1r=bpos(pos); end
        if(level==0)
            endpos=bpos(pos);
            return
        end
    end
    if(c=='[')
        if(isempty(e1l)) e1l=bpos(pos); end
        level=level+1;
        maxlevel=max(maxlevel,level);
    end
    if(c=='"')
        pos=matching_quote(tokens,pos+1);
    end
    pos=pos+1;
end
if(endpos==0)
    error('unmatched "]"');
end

function val=jsonopt(key,default,varargin)
%
% val=jsonopt(key,default,optstruct)
%
% setting options based on a struct. The struct can be produced
% by varargin2struct from a list of 'param','value' pairs
%
% authors:Qianqian Fang (fangq<at> nmr.mgh.harvard.edu)
%
% $Id: loadjson.m 371 2012-06-20 12:43:06Z fangq $
%
% input:
%      key: a string with which one look up a value from a struct
%      default: if the key does not exist, return default
%      optstruct: a struct where each sub-field is a key 
%
% output:
%      val: if key exists, val=optstruct.key; otherwise val=default
%
% license:
%     BSD license, see LICENSE_BSD.txt files for details
%
% -- this function is part of jsonlab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
% 
val=default;
if(nargin<=2) 
    return; 
end
opt=varargin{1};
if(isstruct(opt) && isfield(opt,key))
    val=getfield(opt,key);
end

function opt=varargin2struct(varargin)
%
% opt=varargin2struct('param1',value1,'param2',value2,...)
%   or
% opt=varargin2struct(...,optstruct,...)
%
% convert a series of input parameters into a structure
%
% authors:Qianqian Fang (fangq<at> nmr.mgh.harvard.edu)
% date: 2012/12/22
%
% input:
%      'param', value: the input parameters should be pairs of a string and a value
%       optstruct: if a parameter is a struct, the fields will be merged to the output struct
%
% output:
%      opt: a struct where opt.param1=value1, opt.param2=value2 ...
%
% license:
%     BSD license, see LICENSE_BSD.txt files for details 
%
% -- this function is part of jsonlab toolbox (http://iso2mesh.sf.net/cgi-bin/index.cgi?jsonlab)
%
len=length(varargin);
opt=struct;
if(len==0) return; end
i=1;
while(i<=len)
    if(isstruct(varargin{i}))
        opt=mergestruct(opt,varargin{i});
    elseif(ischar(varargin{i}) && i<len)
        opt=setfield(opt,varargin{i},varargin{i+1});
        i=i+1;
    else
        error('input must be in the form of ...,''name'',value,... pairs or structs');
    end
    i=i+1;
end
