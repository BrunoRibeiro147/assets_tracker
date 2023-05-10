defmodule AssetTracker do
  @fields [:symbol, :settle_date, :quantity, :unit_price, :sell_date]

  defstruct @fields

  def new() do
    :ets.new(:asset_tracker, [:set, :protected, :named_table])
    :ets.insert_new(:asset_tracker, {"sells", []})

    %__MODULE__{}
  end

  def add_purchase(symbol, settle_date, quantity, unit_price) do
    with {:ok, new_settle_date} <- NaiveDateTime.from_iso8601(settle_date),
         new_purchase <- build_new_purchase(new_settle_date, quantity, unit_price) do
      case :ets.lookup(:asset_tracker, symbol) do
        [{_key, purchases}] ->
          :ets.insert(:asset_tracker, {symbol, purchases ++ [new_purchase]})
          %{"#{symbol}" => new_purchase}

        [] ->
          :ets.insert_new(:asset_tracker, {symbol, [new_purchase]})
          %{"#{symbol}" => new_purchase}
      end
    else
      {:error, :invalid_format} ->
        {:error, "Please put a correct settle_date datetime format, Ex: 2023-05-05T10:00:00"}
    end
  end

  defp build_new_purchase(settle_date, quantity, unit_price) do
    %{
      settle_date: settle_date,
      quantity: quantity,
      unit_price: Decimal.new(unit_price)
    }
  end

  def add_sale(symbol, sell_date, quantity, unit_price) do
    with [{_key, purchases}] <- :ets.lookup(:asset_tracker, symbol),
         true <- has_enough_quantity?(purchases, quantity),
         {:ok, format_sell_date} <- NaiveDateTime.from_iso8601(sell_date) do
      new_sale = %{
        symbol: symbol,
        sell_date: format_sell_date,
        quantity: quantity,
        unit_price: unit_price
      }

      [{_key, sells}] = :ets.lookup(:asset_tracker, "sells")

      :ets.insert(:asset_tracker, {"sells", [new_sale | sells]})

      [{_key, purchases}] = :ets.lookup(:asset_tracker, symbol)

      sell_price = Decimal.mult(unit_price, quantity)
      calculate_gain_or_loss(purchases, symbol, quantity, sell_price, Decimal.new(0))
    else
      [] ->
        {:error, "Asset was not found"}

      false ->
        {:error, "This asset does not have enough quantity for this sale"}

      {:error, :invalid_format} ->
        {:error, "Please put a correct sell_date datetime format, Ex: 2023-05-05T10:00:00"}
    end
  end

  defp has_enough_quantity?(purchases, quantity) do
    purchased_total_quantity = Enum.reduce(purchases, 0, &(&1.quantity + &2))

    purchased_total_quantity >= quantity
  end

  defp calculate_gain_or_loss(purchases, symbol, 0, sell_price, paid_price) do
    filter_purchases = Enum.filter(purchases, &(&1.quantity != 0))
    :ets.insert(:asset_tracker, {symbol, filter_purchases})

    gain_or_loss = Decimal.sub(sell_price, paid_price)

    {%{"#{symbol}" => purchases}, gain_or_loss}
  end

  defp calculate_gain_or_loss([purchase | rest], symbol, quantity, sell_price, total_paid_price) do
    %{quantity: purchase_quantity, unit_price: paid_unit_price} = purchase

    new_quantity = purchase_quantity - quantity

    case new_quantity >= 0 do
      true ->
        new_purchase = Map.put(purchase, :quantity, new_quantity)
        paid_value = Decimal.mult(paid_unit_price, quantity)

        calculate_gain_or_loss(
          [new_purchase | rest],
          symbol,
          0,
          sell_price,
          Decimal.add(total_paid_price, paid_value)
        )

      false ->
        paid_value = Decimal.mult(paid_unit_price, purchase_quantity)
        quantity_rest = quantity - purchase_quantity

        calculate_gain_or_loss(
          rest,
          symbol,
          quantity_rest,
          sell_price,
          Decimal.add(total_paid_price, paid_value)
        )
    end
  end
end
