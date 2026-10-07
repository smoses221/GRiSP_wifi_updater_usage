% @doc GRiSP_wifi_updater_test public API.
-module(GRiSP_wifi_updater_test).

-behavior(application).

% Callbacks
-export([start/2]).
-export([stop/1]).

%--- Callbacks -----------------------------------------------------------------

% @private
start(_Type, _Args) -> GRiSP_wifi_updater_test_sup:start_link().

% @private
stop(_State) -> ok.
