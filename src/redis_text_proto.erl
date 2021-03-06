%% Copyright (c) 2011 Jacob Vorreuter <jacob.vorreuter@gmail.com>
%% 
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use,
%% copy, modify, merge, publish, distribute, sublicense, and/or sell
%% copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following
%% conditions:
%% 
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%% 
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
%% OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
%% HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
%% WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
%% OTHER DEALINGS IN THE SOFTWARE.
-module(redis_text_proto).
-export([parse_commands/2]).

-include("nsync.hrl").

parse_commands(<<>>, _Callback) ->
    {ok, <<>>};

parse_commands(<<"*", Rest/binary>>, Callback) ->
    case read_line(Rest, <<>>) of
        {ok, Num0, Rest1} ->
            Num = list_to_integer(binary_to_list(Num0)),
            case parse_num_commands(Rest1, Num, []) of 
                {ok, [Cmd|Args], Rest2} ->
                    Cmd1 = string:to_lower(binary_to_list(Cmd)),
                    nsync_utils:do_callback(Callback, [{cmd, Cmd1, Args}]),
                    parse_commands(Rest2, Callback);
                {error, eof} ->
                    {ok, <<"*", Rest/binary>>}
            end;
        {error, eof} ->
            {ok, <<"*", Rest/binary>>}
    end;

parse_commands(Buffer, _Callback) ->
    case read_line(Buffer, <<>>) of
        {ok, _Line, Rest} ->
            {ok, Rest};
        {error, eof} ->
            {ok, Buffer}
    end.

read_line(<<"\r\n", Rest/binary>>, Acc) ->
    {ok, Acc, Rest};

read_line(<<"\r", _Rest/binary>>, _Acc) ->
    {error, eof};

read_line(<<>>, _Acc) ->
    {error, eof};
    
read_line(<<Char, Rest/binary>>, Acc) ->
    read_line(Rest, <<Acc/binary, Char>>).

parse_num_commands(Rest, 0, Acc) ->
    {ok, lists:reverse(Acc), Rest};

parse_num_commands(<<"$", Rest/binary>>, Num, Acc) ->
    case read_line(Rest, <<>>) of
        {ok, Size0, Rest1} ->
            Size = list_to_integer(binary_to_list(Size0)),
            case read_string(Size, Rest1) of
                {ok, Cmd, Rest2} ->
                    parse_num_commands(Rest2, Num-1, [Cmd|Acc]);
                {error, eof} ->
                    {error, eof}
            end;
        {error, eof} ->
            {error, eof}
    end;

parse_num_commands(_, _Num, _Acc) ->
    {error, eof}.

read_string(Size, Data) ->
    case Data of
        <<Cmd:Size/binary, "\r\n", Rest/binary>> ->
            {ok, Cmd, Rest};
        _ ->
            {error, eof}
    end.
