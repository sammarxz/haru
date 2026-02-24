defmodule TitleTest do
  use Phoenix.Component
  import Phoenix.Component

  def run do
    assigns = %{}
    html = render_to_string(~H"""
      <.live_title default="Haru" suffix=" · Haru">
        <%= assigns[:page_title] %>
      </.live_title>
    """)
    IO.puts("Result without page_title: #{html}")

    assigns = %{page_title: "Haru"}
    html2 = render_to_string(~H"""
      <.live_title default="Haru" suffix=" · Haru">
        <%= assigns[:page_title] %>
      </.live_title>
    """)
    IO.puts("Result with page_title 'Haru': #{html2}")
  end

  defp render_to_string(template), do: Phoenix.HTML.Safe.to_iodata(template) |> IO.iodata_to_binary()
end

TitleTest.run()
