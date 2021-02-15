%%%-------------------------------------------------------------------
%%% @author
%%% AGH University of Science and Technology
%%%-------------------------------------------------------------------
-module(main).

%% API
-export([main/0, logging/1, choosing/2, continuing/3,continuing/1, listing/4, watching/5, get_list/2, get_episode/3, built/2, parse/1, parse_file/1, time_bar/1]).
%-compile([export_all]).

%-import(csv2, [parse/1, parse_file/1]).

main() ->
  spawn(?MODULE, logging, [self()]),
  receive
    {ok, exit} ->
			io:format("\ec"),
			io:format("~n~n~n~n~n~n~n~n			Closing nERLix~n~n~n~n~n~n~n~n"),
      timer:sleep(1000),
      {ok,main}
  end.

logging(MainPID) ->
	io:format("\ec"),
	io:format("					nERLix~n~n"),
	io:format("Who is watching?~n~n"),
	io:format("	[1] User 1~n"),
	io:format("	[2] User 2~n"),
	io:format("	[3] User 3~n"),
	io:format("	[4] User 4~n"),
	io:format("	[5] Kids~n"),
	io:format("~n[0] Exit~n"),
  {ok, [Choice]} = io:fread(">> ", "~d"),
  
  if Choice == 0 ->
      MainPID ! {ok, exit};
    Choice > 5 ->
      io:format("Wrong option! Try again.~n"),
      logging(MainPID);
   	Choice > 0 ->
    	spawn(?MODULE, choosing, [self(), Choice]),
			receive
				{ok, change_user} ->
					logging(MainPID)
			end;
    true ->
      io:format("Wrong option! Try again.~n"),
      logging(MainPID)
  end.


choosing(ParentPID, User) ->
	spawn(?MODULE, get_list, [self(), User]),
	receive
		{ok, List} ->
		io:format("\ec"),
		io:format("					nERLix~n~n"),
		io:format("What will you choose?~n~n"),
		io:format("	[1] Continue watching~n"),
		io:format("	[2] List of series~n"),
		io:format("~n[0] Back~n"),
		{ok, [Choice]} = io:fread("Your choice: ", "~d"),
		if Choice == 0 ->
				ParentPID ! {ok, change_user};
			Choice == 1 ->
				spawn(?MODULE, continuing, [self(), User, List]),
				receive
				{ok, change_option} ->
					choosing(ParentPID, User)
				end;
			Choice == 2 ->
				if User == 5 ->
					spawn(?MODULE, listing, [self(), User, List, 64]);
				true ->
					spawn(?MODULE, listing, [self(), User, List, 6])
				end,
				receive
				{ok, change_option} ->
					choosing(ParentPID, User)
				end;
			true ->
		    io:format("Wrong option! Try again.~n"),
		    choosing(ParentPID, User)
		end
	end.

continuing(User) ->
	io:format("~p", [lists:concat(["./users/", integer_to_list(User), ".txt"])] ).

continuing(ParentPID, User, List) ->
	try
		{ok, Memory} = file:open(lists:concat(["./users/", integer_to_list(User), ".txt"]), [read]),
		Id = list_to_integer(string:trim(io:get_line(Memory, ''))),
		Episode = list_to_integer(string:trim(io:get_line(Memory, ''))),
		file:close(Memory),
		if Id == 0 ->
				io:format("\ec"),
				io:format("No wideos to continiue watching"),
				timer:sleep(1000),
				ParentPID ! {ok, change_option};
			true ->
				spawn(?MODULE, get_episode, [ self(), List, Id]),
				receive
				{ok, {_, Title, _, _, _, _, Episodes}} ->
					io:format("\ec"),
					io:format("	You were watching:~n~n"),
					io:format("		~p~n		Episode: ~w/~w", [Title, Episode, Episodes]),
					io:format("~n~n	Continue watching?~n"),
					io:format("	[1] Yes~n"),
					io:format("	[0] No~n"),
					{ok, [Choice]} = io:fread(">> ", "~d"),
					if Choice == 0 ->
							ParentPID ! {ok, change_option};
						Choice == 1 ->
							spawn(?MODULE, watching, [self(), User, List, Id, Episode]),
							receive
							{ok, change_series} ->
								io:format("Tak"),
								ParentPID ! {ok, change_option}
							end;
						true ->
						  io:format("Wrong option! Try again.~n"),
							continuing(ParentPID, User, List)
					end
				end
		end,
		true
	of
		_ -> {normal}
	catch
		_ -> true
	end.

listing(ParentPID, User, List, Num) ->
	io:format("\ec"),
	io:format("	What will you watch?~n~n"),
	display_list(List, Num),
	io:format("	[~w] More~n", [Num]),
	io:format("~n[0] Back~n"),
	{ok, [Choice]} = io:fread(">> ", "~d"),
	if Choice == 0 ->
				ParentPID ! {ok, change_option};
	Choice < Num ->
		spawn(?MODULE, watching, [self(), User, List, Choice, 1]),
		receive
		{ok, change_series} ->
			listing(ParentPID, User, List, 6)
		end;
	Choice == length(List) ->
		listing(ParentPID, User, List, Num);
	Choice == Num ->
		listing(ParentPID, User, List, Num + 5);
	true ->
	    io:format("Wrong option! Try again.~n"),
	    listing(ParentPID, User, List, Num)
	end.

watching(ParentPID, User, List, Id, Episode) ->
		spawn(?MODULE, get_episode, [ self(), List, Id]),
		receive
		{ok, {Id, Title, _, _, _, _, Episodes}} ->
			try
				{ok, Memory} = file:open(lists:concat(["./users/", integer_to_list(User), ".txt"]), [write]),
				io:format(Memory, "~s~n", [integer_to_list(Id)]),
				io:format(Memory, "~s~n", [integer_to_list(Episode+1)]),
				file:close(Memory),
			true
			of
				_ -> {normal}
			catch
				_ -> true
			end,
			io:format("\ec"),
			io:format("Show: ~p~nEpisodes: ~w~n~n~n~n~n~n			playing episode ~w~n~n~n~n~n~n", [Title, Episodes, Episode]),
			timer:sleep(1000),
			time_bar(70),
			io:format("~n	[0] Back~n"),
			io:format("	[1] Next episode~n"),
			{ok, [Choice]} = io:fread(">> ", "~d"),
			if Episode == (Episodes) ->
					io:format("~nThat was last episode."),
					try
						{ok, Memory2} = file:open(lists:concat(["./users/", integer_to_list(User), ".txt"]), [write]),
						io:format(Memory2, "~s~n", [integer_to_list(0)]),
						io:format(Memory2, "~s~n", [integer_to_list(0)]),
						file:close(Memory2),
					true
					of
						_ -> {normal}
					catch
						_ -> true
					end,
					timer:sleep(1000),
					ParentPID ! {ok, change_series};
			 	Choice == 0 ->
					ParentPID ! {ok, change_series};
			 	Choice == 1 -> 
					watching(ParentPID, User, List, Id, Episode+1);
				true ->
					io:format("Wrong option! Try again.~n"),
					watching(ParentPID, User, List, Id, Episode)
			end
		end.	

time_bar(0)-> io:format("#");
time_bar(Time)->
	io:format("#"),
	timer:sleep(15),
	time_bar(Time-1).


get_list(ParentPID, User) ->
	List = parse_file('./shows_database/NF.csv'),
	ParentPID ! {ok, built(List, User)}.
built([], _) -> [];
built([["0", _, _, _, _, _, _, _, _, _, _, _, _]|T], User) -> built(T, User);
built([[Id, Genre, Title, _, _, _, _, _, Min, Max, Seasons, Episodes, _]|T], 5) -> 
	if ((Genre == "Family Animation") or (Genre == "Family Live Action"))->
		[{list_to_integer(Id), Title, Genre, Seasons, Min, Max, list_to_integer(Episodes)}|built(T, 5)];
		true ->
			built(T, 5)
	end;
built([[Id, Genre, Title, _, _, _, _, _, Min, Max, Seasons, Episodes, _]|T], User) -> 
	[{list_to_integer(Id), Title, Genre, Seasons, Min, Max, list_to_integer(Episodes)}|built(T, User)].


display_list([], _) -> true;
display_list([{Num, _, _, _, _, _, _} | _], Num) -> true;
display_list([{Id, Tittle, _, _, _, _, _} | Others], Num) ->
	io:format("		[~w]  ~p~n", [Id, Tittle]),
	display_list(Others, Num).


get_episode(ParentPID, [{Id, Title, Genre, Seasons, Min, Max, Episodes}|_], Id) ->
	ParentPID !{ok, {Id, Title, Genre, Seasons, Min, Max, Episodes}};
get_episode(ParentPID, [{_, _, _, _, _, _, _}|Others], Id) ->
		get_episode(ParentPID, Others, Id).


parse_file(Fn) ->
{ok, Data} = file:read_file(Fn),
parse(binary_to_list(Data)).

parse(Data) -> lists:reverse(parse(Data, [])).

parse([], Acc) -> Acc;
parse(Data, Acc) ->
{Line, Tail} = parse_line(Data),
parse(Tail, [Line|Acc]).

parse_line(Data) ->
{Line, Tail} = parse_line(Data, []),
{lists:reverse(Line), Tail}.

parse_line([13,10|Data], Acc) -> {Acc, Data};
parse_line([10|Data], Acc) -> {Acc, Data};
parse_line([13|Data], Acc) -> {Acc, Data};
parse_line([], Acc) -> {Acc, []};
parse_line([$,,$,|Data], Acc) -> parse_line(Data, [""|Acc]);
parse_line([$,|Data], Acc) -> parse_line(Data, Acc);
parse_line(Data, Acc) ->
{Fld, Tail} = parse_field(Data),
parse_line(Tail, [Fld|Acc]).

parse_field([$"|Data]) ->
{Fld, Tail} = parse_fieldq(Data, ""),
{lists:reverse(Fld), Tail};
parse_field(Data) ->
{Fld, Tail} = parse_field(Data, ""),
{lists:reverse(Fld), Tail}.

parse_field([$,|Tail], Acc) -> {Acc, [$,|Tail]};
parse_field([13|Tail], Acc) -> {Acc, [13|Tail]};
parse_field([10|Tail], Acc) -> {Acc, [10|Tail]};
parse_field([], Acc) -> {Acc, []};
parse_field([Ch|Tail], Acc) -> parse_field(Tail, [Ch|Acc]).

parse_fieldq([$",$"|Tail], Acc) -> parse_fieldq(Tail, [$"|Acc]);
parse_fieldq([$"|Tail], Acc) -> {Acc, Tail};
parse_fieldq([Ch|Tail], Acc) -> parse_fieldq(Tail, [Ch|Acc]).


