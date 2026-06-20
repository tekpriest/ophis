[
  ~r/Unknown type: (Ecto|Plug).*/,
  ~r/Callback info about the (Ecto|Plug|PromEx).* behaviour is not available./,
  ~r/Function (Ecto|EmailChecker|ExUnit|Paginator|Phoenix|Plug|PromEx).*does not exist./,
  ~r/lib\/mix\/tasks\/ophis\/.*\.ex/,
  ~r/lib\/web\/spec\.ex/,
  {"lib/test/support/conn_case.ex", :no_return},
  {"lib/test/support/test_utils.ex", :no_return},
  {"lib/test/support/test_utils.ex", :call}
]
