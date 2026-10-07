% @doc GRiSP_wifi_updater_test public API.
-module('GRiSP_wifi_updater_test').

-behavior(application).

% Callbacks
-export([start/2]).
-export([stop/1]).

%--- Callbacks -----------------------------------------------------------------

% @private
start(_Type, _Args) ->
    {ok, Sup} = 'GRiSP_wifi_updater_test_sup':start_link(),
    {ok, Color} = application:get_env(led_color),
    {ok, Vsn} = application:get_key(vsn),
    io:format("~n*** GRiSP_wifi_updater_test ~s: LED 2 blinking ~p ***~n",
              [Vsn, Color]),
    grisp_led:flash(2, Color, 500),
    {ok, Sup}.

% @private
stop(_State) -> ok.
