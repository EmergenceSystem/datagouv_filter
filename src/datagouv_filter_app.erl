%%%-------------------------------------------------------------------
%%% @doc data.gouv.fr open-dataset agent (api/1/datasets, open, no key).
%%% Handler: handle/2 -> {RawList, Memory}.
%%% @end
%%%-------------------------------------------------------------------
-module(datagouv_filter_app).
-export([handle/2, base_capabilities/0]).
-define(UA, "Mozilla/5.0 (X11; Linux aarch64; rv:128.0) Gecko/20100101 Firefox/128.0").

-spec base_capabilities() -> [binary()].
base_capabilities() ->
    em_filter:base_capabilities() ++ [<<"opendata">>, <<"france">>, <<"government">>, <<"statistics">>, <<"logement">>, <<"population">>, <<"commune">>, <<"insee">>, <<"budget">>, <<"election">>, <<"sante">>, <<"education">>, <<"transport">>, <<"energie">>, <<"emploi">>, <<"data">>].

handle(Body, Memory) when is_binary(Body) ->
    {gen(extract_value(Body)), Memory};
handle(_Body, Memory) -> {[], Memory}.

gen("") -> [];
gen(Q) ->
    Url = "https://www.data.gouv.fr/api/1/datasets/?q=" ++
          uri_string:quote(Q) ++ "&page_size=25",
    case fetch_json(Url, 12) of
        {ok, #{<<"data">> := Ds}} when is_list(Ds) ->
            [emb(D) || D <- Ds];
        _ -> []
    end.

emb(D) ->
    Title = to_b(maps:get(<<"title">>, D, <<>>)),
    Url   = to_b(maps:get(<<"page">>, D, <<>>)),
    Org   = case maps:get(<<"organization">>, D, null) of
                #{<<"name">> := N} when is_binary(N) -> N;
                _ -> <<"?">>
            end,
    Desc  = snippet(to_b(maps:get(<<"description">>, D, <<>>))),
    #{<<"properties">> => #{
        <<"url">>    => Url,
        <<"title">>  => Title,
        <<"resume">> => fmt("~ts~ts", [Org, Desc])}}.

snippet(<<>>) -> <<>>;
snippet(B) ->
    Clean = re:replace(B, <<"\s+">>, <<" ">>, [global, {return, binary}]),
    Cut   = binary:part(Clean, 0, min(140, byte_size(Clean))),
    <<" - ", Cut/binary>>.

extract_value(Body) ->
    try json:decode(Body) of
        M when is_map(M) ->
            binary_to_list(maps:get(<<"value">>, M, maps:get(<<"query">>, M, <<"">>)));
        _ -> binary_to_list(Body)
    catch _:_ -> binary_to_list(Body) end.

fetch_json(Url, T) ->
    _ = application:ensure_all_started(ssl),
    _ = application:ensure_all_started(inets),
    case httpc:request(get, {Url, [{"User-Agent", ?UA}, {"Accept", "application/json"}]},
                       [{timeout, T * 1000}], [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, B}} -> try {ok, json:decode(B)} catch _:_ -> {error, badjson} end;
        {ok, {{_, C, _}, _, _}}   -> {error, {http, C}};
        {error, R}                -> {error, R}
    end.

to_b(B) when is_binary(B) -> B;
to_b(L) when is_list(L)   -> list_to_binary(L);
to_b(_)                   -> <<>>.
fmt(F, A) -> unicode:characters_to_binary(io_lib:format(F, A)).
