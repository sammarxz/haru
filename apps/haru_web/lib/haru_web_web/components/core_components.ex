defmodule HaruWebWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component
  use Gettext, backend: HaruWebWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-4 right-4 z-50 flex flex-col gap-2"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 p-4 rounded-xl shadow-lg border w-80 sm:w-96 transition-all duration-300",
        @kind == :info && "bg-surface-card border-border-default text-text-primary",
        @kind == :error && "bg-status-error text-text-on-brand border-none"
      ]}>
        <.icon
          :if={@kind == :info}
          name="hero-information-circle"
          class="size-5 shrink-0 text-action-primary"
        />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div class="flex-1">
          <p :if={@title} class="font-semibold text-sm">{@title}</p>
          <p class="text-sm leading-relaxed">{msg}</p>
        </div>
        <button
          type="button"
          class="group self-start cursor-pointer transition-opacity hover:opacity-70"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled form)
  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary secondary strong danger)
  attr :size, :string, values: ~w(sm md lg), default: "md"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{
      "primary" =>
        "bg-action-primary text-text-on-brand hover:bg-action-primary-hover shadow-button-primary",
      "secondary" =>
        "bg-neutral-100 text-text-primary border border-neutral-200 hover:bg-neutral-200 hover:border-neutral-300",
      "strong" => "bg-action-strong text-text-on-dark shadow-md hover:bg-action-strong-hover",
      "danger" => "bg-status-error text-white hover:bg-red-700 shadow-sm",
      nil =>
        "bg-neutral-100 text-text-primary border border-neutral-200 hover:bg-neutral-200 hover:border-neutral-300"
    }

    sizes = %{
      "sm" => "px-4 py-1.5 text-sm gap-1.5",
      "md" => "px-6 py-3 text-sm gap-2",
      "lg" => "px-8 py-4 text-base gap-2"
    }

    assigns =
      assign(assigns, :class, [
        "cursor-pointer inline-flex items-center justify-center rounded-md font-semibold transition-all active:scale-98 disabled:opacity-45 disabled:cursor-not-allowed",
        Map.get(sizes, assigns[:size], sizes["md"]),
        Map.get(variants, assigns[:variant], variants[nil]),
        assigns[:class]
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any, default: nil

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign(:value, assigns.value || field.value)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-4">
      <label class="flex items-center gap-2 cursor-pointer group">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={[
            "size-4 rounded border-border-default text-action-primary focus:ring-border-focus transition-all",
            @class
          ]}
          {@rest}
        />
        <span
          :if={@label}
          class="text-sm font-medium text-text-secondary group-hover:text-text-primary transition-colors"
        >
          {@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block">
        <span :if={@label} class="block text-sm font-medium text-text-secondary mb-1.5">
          {@label}
        </span>
        <select
          id={@id}
          name={@name}
          class={[
            "block w-full rounded-sm bg-surface-card border border-border-default px-3 py-2 text-text-primary text-base transition-all hover:border-text-muted focus:border-border-focus focus:ring-4 focus:ring-action-primary/15 outline-none disabled:bg-surface-section disabled:opacity-60 disabled:cursor-not-allowed",
            @errors != [] &&
              "border-status-error focus:border-status-error focus:ring-status-error/12",
            @class
          ]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block">
        <span :if={@label} class="block text-sm font-medium text-text-secondary mb-1.5">
          {@label}
        </span>
        <textarea
          id={@id}
          name={@name}
          class={[
            "block w-full rounded-sm bg-surface-card border border-border-default px-3 py-2 text-text-primary text-base min-h-[100px] transition-all hover:border-text-muted focus:border-border-focus focus:ring-4 focus:ring-action-primary/15 outline-none disabled:bg-surface-section disabled:opacity-60 disabled:cursor-not-allowed",
            @errors != [] &&
              "border-status-error focus:border-status-error focus:ring-status-error/12",
            @class
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block">
        <span :if={@label} class="block text-sm font-medium text-text-secondary mb-1.5">
          {@label}
        </span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            "block w-full rounded-sm bg-neutral-100 border border-neutral-200 px-4 py-3 text-text-primary text-base transition-all hover:border-text-muted focus:border-border-focus focus:ring-4 focus:ring-action-primary/15 outline-none placeholder:text-text-muted disabled:bg-surface-section disabled:opacity-60 disabled:cursor-not-allowed",
            @errors != [] &&
              "border-status-error focus:border-status-error focus:ring-status-error/12",
            @class
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-2 flex gap-1.5 items-center text-xs font-medium text-status-error">
      <.icon name="hero-exclamation-circle" class="size-3.5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["mb-8", @actions != [] && "flex items-center justify-between gap-6"]}>
      <div>
        <h1 class="text-2xl font-bold text-text-primary tracking-tight">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-1 text-sm text-text-secondary">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="overflow-hidden rounded-xl border border-border-subtle bg-surface-card shadow-card">
      <table class="w-full border-collapse text-left">
        <thead class="bg-surface-section border-b border-border-subtle">
          <tr>
            <th
              :for={col <- @col}
              class="px-4 py-3 text-xs font-semibold text-text-secondary uppercase tracking-wider"
            >
              {col[:label]}
            </th>
            <th :if={@action != []} class="px-4 py-3">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}
          class="divide-y divide-border-subtle"
        >
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="group hover:bg-surface-section transition-colors"
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["px-4 py-4 text-sm text-text-primary", @row_click && "hover:cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="px-4 py-4 w-0 flex justify-end">
              <div class="flex gap-3">
                <%= for action <- @action do %>
                  <div class="text-sm font-medium text-action-primary hover:text-action-primary-hover">
                    {render_slot(action, @row_item.(row))}
                  </div>
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="rounded-xl border border-border-subtle bg-white shadow-card overflow-hidden">
      <ul class="divide-y divide-border-subtle">
        <li
          :for={item <- @item}
          class="p-4 hover:bg-surface-section transition-colors flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2"
        >
          <div class="text-sm font-medium text-text-secondary uppercase tracking-wider text-xs">
            {item.title}
          </div>
          <div class="text-sm text-text-primary font-medium">{render_slot(item)}</div>
        </li>
      </ul>
    </div>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :id, :any, default: nil
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span id={@id} class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Renders a modal overlay.

  ## Examples

      <.modal show={@show_modal}>
        <h2>Title</h2>
        <p>Content</p>
      </.modal>
  """
  attr :show, :boolean, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      :if={@show}
      class="fixed inset-0 z-50 flex items-center justify-center p-4 bg-text-primary/40 backdrop-blur-sm"
    >
      <div class={[
        "bg-surface-card rounded-2xl border border-border-subtle shadow-lg max-w-md w-full p-8 animate-in fade-in zoom-in-95 duration-200",
        @class
      ]}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a badge label.

  ## Examples

      <.badge variant="success">Active</.badge>
  """
  attr :variant, :string, values: ~w(default success warning error brand), default: "default"
  slot :inner_block, required: true

  def badge(assigns) do
    variant_classes = %{
      "default" => "bg-surface-subtle text-text-secondary",
      "success" => "bg-status-success/10 text-status-success",
      "warning" => "bg-status-warning/10 text-status-warning",
      "error" => "bg-status-error/10 text-status-error",
      "brand" => "bg-action-primary/10 text-action-primary"
    }

    assigns =
      assign(
        assigns,
        :variant_class,
        Map.get(variant_classes, assigns.variant, variant_classes["default"])
      )

    ~H"""
    <span class={["rounded-full px-3 py-1 text-xs font-medium", @variant_class]}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders a stat card with label, value, and optional delta indicator.

  ## Examples

      <.stat_card label="Visitors" value="1,234" delta="+12%" delta_positive={true} />
  """
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :delta, :string, default: nil
  attr :delta_positive, :boolean, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class="flex flex-col min-w-[120px]">
      <div class="flex items-center gap-1.5 mb-1.5 opacity-80">
        <span class="text-[13px] font-medium text-text-secondary">{@label}</span>
      </div>
      <span class="text-[28px] font-bold text-text-primary leading-none tracking-tight mb-2">
        {@value}
      </span>
      <span
        :if={@delta}
        class={[
          "inline-block text-[10px] font-bold px-1.5 py-0.5 rounded-[4px] w-fit",
          stat_delta_bg_class(@delta_positive),
          stat_delta_class(@delta_positive)
        ]}
      >
        {@delta}
      </span>
    </div>
    """
  end

  defp stat_delta_class(nil), do: "text-text-muted"
  defp stat_delta_class(true), do: "text-[#10b981]"
  defp stat_delta_class(false), do: "text-[#ef4444]"

  defp stat_delta_bg_class(nil), do: "bg-surface-section"
  defp stat_delta_bg_class(true), do: "bg-[#10b981]/15"
  defp stat_delta_bg_class(false), do: "bg-[#ef4444]/15"

  @doc """
  Renders a tabbed data panel card.

  ## Examples

      <.panel id="pages-panel" active_tab={@pages_tab} table="pages">
        <:tab value="top" label="Top pages" />
        <:tab value="entered" label="Entry pages" />
        <div>content</div>
      </.panel>
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :active_tab, :string, required: true
  attr :table, :string, required: true
  attr :event, :string, default: "set_tab"

  slot :tab, required: true do
    attr :value, :string, required: true
    attr :label, :string, required: true
  end

  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <div
      id={@id}
      class="bg-white rounded-2xl border border-border-subtle shadow-[0_2px_8px_rgba(0,0,0,0.02)] overflow-hidden flex flex-col h-full"
    >
      <div class="flex items-center justify-between px-6 py-5">
        <h3 class="font-bold text-text-primary text-[15px]">{@title}</h3>
        <div :if={@tab != []} class="flex bg-[#F4F4F5] rounded-full p-0.5 gap-0.5">
          <button
            :for={tab <- @tab}
            phx-click={@event}
            phx-value-table={@table}
            phx-value-tab={tab.value}
            class={[
              "text-[12px] font-medium px-3 py-1.5 rounded-full transition-all leading-none",
              if(@active_tab == tab.value,
                do: "bg-white text-text-primary shadow-[0_1px_3px_rgba(0,0,0,0.06)]",
                else: "text-[#71717A] hover:text-text-primary"
              )
            ]}
          >
            {tab.label}
          </button>
        </div>
      </div>
      <div class="px-6 pb-6 pt-1 flex-grow space-y-[14px]">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a consistent dropdown menu container.
  """
  attr :show, :boolean, required: true
  attr :on_click_away, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def dropdown_menu(assigns) do
    ~H"""
    <div
      :if={@show}
      phx-click-away={@on_click_away}
      class={[
        "absolute top-full mt-2 bg-white border border-neutral-200 rounded-xl shadow-[0_4px_12px_rgba(0,0,0,0.08)] z-50 py-1.5 animate-in fade-in slide-in-from-top-1 overflow-hidden",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a header title inside a dropdown menu.
  """
  slot :inner_block, required: true
  attr :class, :string, default: ""

  def dropdown_header(assigns) do
    ~H"""
    <div class={["px-3 py-1.5 text-sm font-medium text-neutral-400", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a clickable item inside a dropdown menu.
  """
  attr :rest, :global, include: ~w(href method navigate patch), doc: "Arbitrary HTML attributes such as href, phx-click, etc."
  attr :class, :string, default: ""
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  def dropdown_item(assigns) do
    ~H"""
    <%= if Map.has_key?(@rest, :href) or Map.has_key?(@rest, :navigate) or Map.has_key?(@rest, :method) do %>
      <.link
        class={[
          "w-full flex items-center justify-between text-left px-2 py-1.5 text-sm font-medium transition-colors rounded-md mx-1.5",
          "calc(100% - 12px)",
          if(@active,
            do: "hover:bg-neutral-100 text-text-primary",
            else: "text-neutral-500 hover:bg-neutral-100 hover:text-text-primary"
          ),
          @class
        ]}
        style="width: calc(100% - 12px);"
        {@rest}
      >
        {render_slot(@inner_block)}
      </.link>
    <% else %>
      <button
        class={[
          "w-full flex items-center gap-2 text-left px-2 py-1.5 text-sm font-medium transition-colors rounded-md mx-1.5",
          "calc(100% - 12px)",
          if(@active,
            do: "hover:bg-neutral-100 text-text-primary",
            else: "text-neutral-500 hover:bg-neutral-100 hover:text-text-primary"
          ),
          @class
        ]}
        style="width: calc(100% - 12px);"
        {@rest}
      >
        {render_slot(@inner_block)}
      </button>
    <% end %>
    """
  end

  @doc """
  Renders a divider line inside a dropdown menu.
  """
  def dropdown_divider(assigns) do
    ~H"""
    <div class="my-1.5 border-t border-[#E5E5E5] w-full"></div>
    """
  end

  @doc """
  Renders a row with a progress bar background relative to a max value.
  """
  attr :value, :integer, required: true
  attr :max, :integer, required: true
  slot :title, required: true
  slot :inner_block

  def progress_row(assigns) do
    ~H"""
    <% pct = if @max > 0, do: Float.round(@value / @max * 100, 1), else: 0 %>
    <div class="group relative flex items-center justify-between py-2 px-2.5 rounded-md z-0 overflow-hidden transition-colors">
      <div
        class="absolute top-0 bottom-0 left-0 bg-[#F4F4F5] group-hover:bg-[#E4E4E7] rounded-md -z-10 transition-all duration-500 ease-out"
        style={"width: #{pct}%"}
      >
      </div>
      <div class="flex items-center gap-2 flex-1 mr-4 text-[13px] font-medium text-[#52525B] truncate group-hover:text-text-primary z-10 transition-colors">
        {render_slot(@title)}
      </div>
      <span class="text-[13px] font-bold text-text-primary tabular-nums z-10">{@value}</span>
    </div>
    """
  end

  @doc """
  Renders a settings-style section card with an optional footer.

  ## Examples

      <.section_card>
        <h3>Section title</h3>
        <p>Content</p>
        <:footer>
          <span>Footer note</span>
          <button>Action</button>
        </:footer>
      </.section_card>
  """
  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(default danger), default: "default"
  slot :inner_block, required: true
  slot :footer

  def section_card(assigns) do
    ~H"""
    <section class={[
      "rounded-xl border transition-all overflow-hidden",
      @variant == "danger" && "bg-red-50 border-red-200",
      @variant != "danger" && "border-neutral-200",
      @class
    ]}>
      <div class="p-6">
        {render_slot(@inner_block)}
      </div>
      <div
        :if={@footer != []}
        class={[
          "border-t px-6 py-3",
          if(@variant == "danger",
            do: "bg-red-100 border-red-200",
            else: "bg-neutral-100 border-neutral-200"
          )
        ]}
      >
        {render_slot(@footer)}
      </div>
    </section>
    """
  end

  @doc """
  Renders an empty state with optional icon, title, description, and actions.

  ## Examples

      <.empty_state icon="hero-chart-bar">
        <:title>No data yet</:title>
        Add your first site to start tracking.
        <:actions>
          <.button href="/sites/new">Add a site</.button>
        </:actions>
      </.empty_state>
  """
  attr :icon, :string, default: nil
  slot :icon_block
  slot :title, required: true
  slot :inner_block
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-16 px-8">
      <div
        :if={@icon_block != [] || @icon}
        class="size-20 bg-neutral-100 border border-neutral-200 rounded-full flex items-center justify-center mx-auto mb-6"
      >
        <%= if @icon_block != [] do %>
          {render_slot(@icon_block)}
        <% else %>
          <.icon name={@icon} class="size-10 text-text-muted" />
        <% end %>
      </div>
      <h2 class="text-xl font-semibold text-text-primary">{render_slot(@title)}</h2>
      <div :if={@inner_block != []} class="text-sm text-text-secondary max-w-xs mx-auto mt-2">
        {render_slot(@inner_block)}
      </div>
      <div :if={@actions != []} class="mt-6">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  @doc """
  Shared authenticated app navigation bar.

  Renders the Haru logo on the left with an optional breadcrumb slot,
  and an optional right slot for per-page actions. When `current_user`
  is provided, a user avatar button and dropdown menu are rendered
  automatically — no parent state required.

  ## Examples

      <.app_nav current_user={@current_user}>
        <:breadcrumb>
          <span class="text-xs font-semibold text-text-secondary">Settings</span>
        </:breadcrumb>
        <:right>
          <button phx-click="toggle_snippet">Get snippet</button>
        </:right>
      </.app_nav>
  """
  attr :current_user, :map, default: nil
  attr :id, :string, default: "app-nav"
  slot :breadcrumb
  slot :right

  def app_nav(assigns) do
    ~H"""
    <nav class="bg-surface-card py-3">
      <div class="max-w-3xl mx-auto flex items-center justify-between px-4">
        <div class="flex items-center gap-3">
          <a href="/dashboard" class="flex items-center gap-2">
            <img src="/images/logo-symbol.svg" width="36" height="36" />
          </a>
          {render_slot(@breadcrumb)}
        </div>
        <div class="flex items-center gap-4">
          {render_slot(@right)}
          <div :if={@current_user} class="relative">
            <button
              phx-click={JS.toggle(to: "##{@id}-user-dropdown")}
              class="size-8 rounded-full bg-neutral-100 border border-neutral-200 flex items-center justify-center text-xs font-bold text-text-secondary hover:bg-neutral-100 transition-all shadow-sm active:scale-95 overflow-hidden"
            >
              <img
                :if={Map.get(@current_user, :avatar_url)}
                src={@current_user.avatar_url}
                class="size-full object-cover"
              />
              <span :if={!Map.get(@current_user, :avatar_url)}>
                {String.first(@current_user.email) |> String.upcase()}
              </span>
            </button>
            <div
              id={"#{@id}-user-dropdown"}
              class="hidden absolute right-0 top-full mt-2 min-w-[220px] bg-white border border-neutral-200 rounded-xl shadow-[0_4px_12px_rgba(0,0,0,0.08)] z-50 py-1.5 overflow-hidden"
              phx-click-away={JS.hide(to: "##{@id}-user-dropdown")}
            >
              <div class="px-2 py-2 mb-1 flex items-center gap-3">
                <div class="size-9 rounded-full bg-neutral-100 border border-neutral-200 flex flex-shrink-0 items-center justify-center text-xs font-bold text-text-secondary overflow-hidden">
                  <img
                    :if={Map.get(@current_user, :avatar_url)}
                    src={@current_user.avatar_url}
                    class="size-full object-cover"
                  />
                  <span :if={!Map.get(@current_user, :avatar_url)}>
                    {String.first(@current_user.email) |> String.upcase()}
                  </span>
                </div>
                <div class="flex flex-col truncate">
                  <span class="text-[14px] font-medium text-text-primary leading-tight truncate">
                    {Map.get(@current_user, :name, @current_user.email)}
                  </span>
                  <span
                    :if={Map.get(@current_user, :name)}
                    class="text-[12px] text-neutral-400 leading-tight truncate mt-0.5"
                  >
                    {@current_user.email}
                  </span>
                </div>
              </div>
              <.dropdown_item href="/settings">
                Account <.icon name="hero-cog-8-tooth" class="size-4 text-neutral-400" />
              </.dropdown_item>
              <.dropdown_divider />
              <.dropdown_item href="/dashboard">
                Dashboard <.icon name="hero-chart-bar" class="size-4 text-neutral-400" />
              </.dropdown_item>
              <.dropdown_item href="https://buymeacoffee.com/smarxz">
                Donate <.icon name="hero-heart" class="size-4 text-neutral-400" />
              </.dropdown_item>
              <.dropdown_item href="mailto:sammarxz@proton.me">
                Contact <.icon name="hero-envelope" class="size-4 text-neutral-400" />
              </.dropdown_item>
              <.dropdown_divider />
              <.dropdown_item href="/logout" method="delete">
                Log out <.icon name="hero-arrow-right-on-rectangle" class="size-4 text-neutral-400" />
              </.dropdown_item>
            </div>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  @doc """
  Password input with a show/hide visibility toggle button.
  Supports both `field=` (LiveView form field) and direct `name=`/`value=` usage.
  Uses a client-side JS dispatch event — no server round-trip needed.

  ## Examples

      <.password_input name="password" id="password" label="Password" required />
      <.password_input field={@form[:password]} label="New password" />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any, default: nil
  attr :field, Phoenix.HTML.FormField
  attr :errors, :list, default: []
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(autocomplete disabled form placeholder required)

  def password_input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> field.name end)
    |> assign(:value, assigns.value || field.value)
    |> password_input()
  end

  def password_input(assigns) do
    ~H"""
    <div class="mb-4">
      <label class="block">
        <span :if={@label} class="block text-sm font-medium text-text-secondary mb-1.5">
          {@label}
        </span>
        <div class="relative">
          <input
            id={@id}
            type="password"
            name={@name}
            value={Phoenix.HTML.Form.normalize_value("password", @value)}
            class={[
              "block w-full rounded-sm bg-neutral-100 border border-neutral-200 px-4 py-3 pr-11 text-text-primary text-base transition-all hover:border-text-muted focus:border-border-focus focus:ring-4 focus:ring-action-primary/15 outline-none placeholder:text-text-muted disabled:bg-surface-section disabled:opacity-60 disabled:cursor-not-allowed",
              @errors != [] &&
                "border-status-error focus:border-status-error focus:ring-status-error/12",
              @class
            ]}
            {@rest}
          />
          <button
            type="button"
            tabindex="-1"
            aria-label="Toggle password visibility"
            phx-click={
              JS.dispatch("haru:toggle-password", to: "##{@id}")
              |> JS.toggle(to: "##{@id}-eye")
              |> JS.toggle(to: "##{@id}-eye-slash")
            }
            class="absolute right-3 top-1/2 -translate-y-1/2 p-0.5 text-text-muted hover:text-text-secondary transition-colors"
          >
            <.icon name="hero-eye" id={"#{@id}-eye"} class="size-4" />
            <.icon name="hero-eye-slash" id={"#{@id}-eye-slash"} class="size-4 hidden" />
          </button>
        </div>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  @doc """
  Password strength meter — renders 4 bars that fill based on strength score (0–4).
  Meant to be placed right after a `password_input` component.

  Strength is calculated server-side and passed as an integer:
  - 0: no input (hidden)
  - 1: weak
  - 2: fair
  - 3: good
  - 4: strong

  ## Examples

      <.password_strength strength={@password_strength} />
  """
  attr :strength, :integer, required: true

  def password_strength(assigns) do
    ~H"""
    <div :if={@strength > 0} class="-mt-2 mb-4">
      <div class="flex gap-1 mb-1">
        <div
          :for={i <- 1..4}
          class={[
            "h-1 flex-1 rounded-full transition-all duration-300",
            strength_bar_class(@strength, i)
          ]}
        />
      </div>
      <p class={["text-xs font-medium", strength_text_class(@strength)]}>
        {strength_label(@strength)}
      </p>
    </div>
    """
  end

  defp strength_bar_class(strength, i) when i <= strength do
    case strength do
      1 -> "bg-red-400"
      2 -> "bg-orange-400"
      3 -> "bg-yellow-400"
      _ -> "bg-green-500"
    end
  end

  defp strength_bar_class(_, _), do: "bg-neutral-200"

  defp strength_text_class(1), do: "text-red-500"
  defp strength_text_class(2), do: "text-orange-500"
  defp strength_text_class(3), do: "text-yellow-600"
  defp strength_text_class(_), do: "text-green-600"

  defp strength_label(1), do: "Weak"
  defp strength_label(2), do: "Fair"
  defp strength_label(3), do: "Good"
  defp strength_label(_), do: "Strong"

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(HaruWebWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(HaruWebWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end

