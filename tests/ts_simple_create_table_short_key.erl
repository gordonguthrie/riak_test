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

-module(ts_simple_create_table_short_key).

-behavior(riak_test).

-include_lib("eunit/include/eunit.hrl").

-export([confirm/0]).

confirm() ->
    DDL =
        "CREATE TABLE GeoCheckin ("
        " myfamily    varchar   not null,"
        " myseries    varchar   not null,"
        " time        timestamp not null,"
        " weather     varchar   not null,"
        " temperature double,"
        " PRIMARY KEY ((quantum(time, 15, 'm'), myfamily),"
        " time, myfamily))",
    {ok, Got} = ts_util:create_bucket_type(ts_util:build_cluster(single), DDL),
    ?assertNotEqual(0, string:str(Got, "Primary key must consist of exactly 3 field")),
    pass.
