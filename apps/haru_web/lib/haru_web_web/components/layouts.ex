defmodule HaruWebWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HaruWebWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="border-b border-border-subtle bg-surface-page px-4 py-4 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl flex items-center justify-between">
        <div class="flex items-center gap-3">
          <a href="/" class="flex items-center gap-2">
            <img src={~p"/images/logo.svg"} width="32" height="32" class="rounded-md shadow-sm" />
            <span class="text-lg font-bold text-text-primary tracking-tight">Haru</span>
          </a>
        </div>
        <nav class="flex items-center gap-4">
          <ul class="flex items-center gap-2 text-sm font-medium text-text-secondary">
            <li>
              <a
                href="#"
                class="px-3 py-2 rounded-md hover:bg-surface-section hover:text-text-primary transition-colors"
              >
                Docs
              </a>
            </li>
            <li>
              <a
                href="#"
                class="px-3 py-2 rounded-md hover:bg-surface-section hover:text-text-primary transition-colors"
              >
                GitHub
              </a>
            </li>
            <li class="ml-2 border-l border-border-subtle pl-4 flex items-center gap-4">
              <.theme_toggle />
              <a
                href="#"
                class="bg-action-strong text-text-on-dark px-4 py-2 rounded-md font-semibold shadow-md hover:bg-action-strong-hover active:scale-95 transition-all"
              >
                Sign In
              </a>
            </li>
          </ul>
        </nav>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex flex-row items-center border border-border-default bg-surface-section rounded-full p-0.5">
      <div class="absolute w-1/3 h-[calc(100%-4px)] rounded-full bg-surface-card border border-border-subtle shadow-sm left-0.5 [[data-theme=light]_&]:left-[calc(33.333%+1px)] [[data-theme=dark]_&]:left-[calc(66.666%+1px)] transition-[left] duration-200" />
      <button
        class="flex p-1.5 cursor-pointer w-1/3 z-10 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon
          name="hero-computer-desktop-micro"
          class="size-4 text-text-muted hover:text-text-primary"
        />
      </button>
      <button
        class="flex p-1.5 cursor-pointer w-1/3 z-10 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 text-text-muted hover:text-text-primary" />
      </button>
      <button
        class="flex p-1.5 cursor-pointer w-1/3 z-10 justify-center"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 text-text-muted hover:text-text-primary" />
      </button>
    </div>
    """
  end
end

