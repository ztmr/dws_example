-module (dws_example_service).
-export ([
          echo/2,
          ping/1,
          get_system_processes/1,
          get_mnesia_info/1,
          reveal_session_data/1
         ]).

-export ([autoregister/0]).
-on_load (autoregister/0).

-include_lib ("stdlib/include/qlc.hrl").
-include_lib ("dws/include/dws_session.hrl").

autoregister () ->
    %% Note: this will happen when the module is loaded, so:
    %%   (1) when the application starts `autoregister' will be probably called
    %%       _before_ the `sys.config' is processed
    %%   (2) when the application is being upgraded, the `autoregister' will most
    %%       likely override the `sys.config' value since called later
    NS1 = <<"DWS.Service.Example">>,  %% This would override the definition from sys.config
    NS2 = <<"DWS.Service.Autodeploy.Example">>,  %% This would add something more
    ok = dws_service_broker:add_service_handler_async (NS1, ?MODULE),
    ok = dws_service_broker:add_service_handler_async (NS2, ?MODULE),
    ok.

echo (_SessionID, Msg) -> {ok, Msg}.

ping (_SessionID) -> {ok, pong}.

get_system_processes (_SessionID) ->
    {ok, {array, [
                  {struct, [{pid_to_list (Pid), get_process_ancestors (Pid)}]}
                  || Pid <- erlang:processes ()
                 ]}}.

get_mnesia_info (_SessionID) ->
    A = fun (X) -> {array, X} end,  %% Array
    S = fun (X) -> X end,           %% Scalar
    Props = [
             {extra_db_nodes, A},
             {db_nodes, A},
             {running_db_nodes, A},
             {is_running, S},
             {local_tables, A},
             {tables, A}
            ],
    Info = [ {K, F (mnesia:system_info (K))}
             || {K, F} <- Props ],
    {ok, {struct, Info}}.

reveal_session_data (_SessionID) ->
    Fun = fun () ->
                  qlc:eval (qlc:q ([ {struct,
                                      [{id, X#session.id},
                                       {created, now2iso (X#session.created)},
                                       {state, x2str (X#session.state)}]}
                                     || X <- mnesia:table (session) ]))
          end,
    {atomic, Sessions} = mnesia:transaction (Fun),
    {ok, {array, Sessions}}.


%% === Private functions ===

now2iso (X) ->
    iolist_to_binary (idealib_dt:dt2iso (idealib_dt:now2dt (X))).
x2str (X) ->
    iolist_to_binary (io_lib:format("~w", [X])).

proc_to_list (undefined) -> null;
proc_to_list (Pid) when is_pid (Pid) -> pid_to_list (Pid);
proc_to_list (Name) when is_atom (Name) -> atom_to_list (Name).

get_process_ancestors (Pid) ->
    ProcInfo = erlang:process_info (Pid),
    Dict = proplists:get_value (dictionary, ProcInfo, []),
    Ancestors = proplists:get_value ('$ancestors', Dict, []),
    {array, [ proc_to_list (A) || A <- Ancestors ]}.

