-module(replication_object_reformat).
-behavior(riak_test).
-export([confirm/0]).
-include_lib("eunit/include/eunit.hrl").

-import(rt, [deploy_nodes/2]).

-define(TEST_BUCKET, <<"repl-aae-fullsync-systest_a">>).
-define(NUM_KEYS,    1000).

-define(CONF(Retries), [
        {riak_core,
            [
             {ring_creation_size, 8},
             {default_bucket_props, [{n_val, 1}]}
            ]
        },
        {riak_kv,
            [
             {object_format, v1},
             {anti_entropy, {on, []}},
             {anti_entropy_build_limit, {100, 1000}},
             {anti_entropy_concurrency, 100}
            ]
        },
        {riak_repl,
         [
          {fullsync_strategy, aae},
          {fullsync_on_connect, false},
          {fullsync_interval, disabled},
          {max_fssource_retries, Retries}
         ]}
        ]).

confirm() ->
    Nodes = deploy_nodes(6, ?CONF(5)),

    {ANodes, BNodes} = lists:split(3, Nodes),

    lager:info("ANodes: ~p", [ANodes]),
    lager:info("BNodes: ~p", [BNodes]),

    lager:info("Building two clusters."),
    [repl_util:make_cluster(N) || N <- [ANodes, BNodes]],

    lager:info("Updating app config to force v0 on sink cluster."),
    [rt:update_app_config(N, [{riak_kv, [{object_format, v0}]}])
     || N <- BNodes],

    AFirst = hd(ANodes),
    BFirst = hd(BNodes),

    lager:info("Naming clusters."),
    repl_util:name_cluster(AFirst, "A"),
    repl_util:name_cluster(BFirst, "B"),

    lager:info("Waiting for convergence."),
    rt:wait_until_ring_converged(ANodes),
    rt:wait_until_ring_converged(BNodes),

    lager:info("Waiting for transfers to complete."),
    rt:wait_until_transfers_complete(ANodes),
    rt:wait_until_transfers_complete(BNodes),

    lager:info("Wait for v1 capability on source cluster."),
    [rt:wait_until_capability(N, {riak_kv, object_format}, v1, v0)
     || N <- ANodes],

    lager:info("Wait for v0 capability on sink cluster."),
    [rt:wait_until_capability(N, {riak_kv, object_format}, v0, v0)
     || N <- BNodes],

    lager:info("Get leaders."),
    LeaderA = rt:repl_get_leader(AFirst),
    LeaderB = rt:repl_get_leader(BFirst),

    lager:info("Finding connection manager ports."),
    BPort = rt:repl_get_port(LeaderB),

    lager:info("Connecting cluster A to B"),
    rt:repl_connect_cluster(LeaderA, BPort, "B"),

    lager:info("Write keys, assert they are not available yet."),
    rt:write_to_cluster(AFirst, 1, ?NUM_KEYS, ?TEST_BUCKET),
    rt:read_from_cluster(BFirst, 1, ?NUM_KEYS, ?NUM_KEYS, ?TEST_BUCKET),

    lager:info("Enabling fullsync from A to B"),
    repl_util:enable_fullsync(LeaderA, "B"),
    rt:wait_until_ring_converged(ANodes),

    rt:validate_completed_fullsync(LeaderA, BFirst, "B", 1, ?NUM_KEYS, ?TEST_BUCKET).
