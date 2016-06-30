%% -------------------------------------------------------------------
%%
%% Copyright (c) 2015 Basho Technologies, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
%% @doc A module to test riak_ts basic create bucket/put/select cycle,
%%      with a node down.

-module(ts_degraded_handoff).

-behavior(riak_test).

-include_lib("eunit/include/eunit.hrl").

-export([confirm/0]).

confirm() ->
    %%
    %% this is a regression test for a handoff bug
    %%

    %% Step 1
    %% * setup a 3-node cluster write some data to
    %% * generate a DDL, some data, a query and the expected response
    DDL = ts_util:get_ddl(),
    gg:format("DDL is ~p~n", [DDL]),
    Bucket = ts_util:get_default_bucket(),
    gg:format("Bucket is ~p~n", [Bucket]),
    SeqFun = fun() -> lists:seq(1, 30) end,
    Data = ts_util:get_valid_select_data(SeqFun),
    gg:format("Data is ~p~n", [Data]),
    Qry = ts_util:get_valid_qry(),
    gg:format("Qry is ~p~n", [Qry]),
    Expected = {ok, {
        ts_util:get_cols(),
        ts_util:exclusive_result_from_data(Data, 2, 9)}},
    gg:format("Expected is ~p~n", [Expected]),

    %% Step 2
    %% * build the cluster
    %% * create and activate the table
    %% * write the data to it
    [Node1, Node2, Node3] = Cluster = ts_util:build_cluster(multiple),
    gg:format("Nodes are ~p~n", [Cluster]),
    Conn = rt:pbc(Node1),
    gg:format("Conn is ~p~n", [Conn]),
    {ok, _} = ts_util:create_and_activate_bucket_type(Cluster, DDL, Bucket),

    gg:format("Node1 is ~p Node2 is ~p Node3 is ~p~n", [Node1, Node2, Node3]),
    ok = riakc_ts:put(Conn, Bucket, Data),

    %% Step 3
    %% * drop a node
    Ret = rt:remove(Node1, Node2),
    gg:format("Ret is ~p~n", [Ret]),

    %% Step 4
    %% * read the data
    %% Got = ts_util:ts_query(ClusterConn, normal, DDL, Data, Qry),
    Got = ts_util:single_query(Conn, Qry),
    gg:format("Got is ~p~n", [Got]),

    ?assertEqual(Expected, Got),
    pass.
