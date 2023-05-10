defmodule AssetTrackerTest do
  use ExUnit.Case
  doctest AssetTracker

  describe "new/0" do
    test "should return a AssetTracker struct" do
      assert %AssetTracker{} == AssetTracker.new()
    end

    test "should create an ets table with an empty sells array" do
      AssetTracker.new()

      assert [{"sells", []}] = :ets.lookup(:asset_tracker, "sells")
    end
  end

  describe "add_purchase/4" do
    setup do
      AssetTracker.new()

      params = %{
        symbol: "ASD",
        settle_date: "2023-05-05T10:00:00",
        quantity: 10,
        unit_price: 4
      }

      %{params: params}
    end

    test "should add a new add_purchase", %{params: params} do
      %{
        symbol: symbol,
        settle_date: settle_date,
        quantity: quantity,
        unit_price: unit_price
      } = params

      decimal_unit_price = Decimal.new(unit_price)

      assert %{
               "ASD" => %{
                 quantity: ^quantity,
                 settle_date: ~N[2023-05-05 10:00:00],
                 unit_price: ^decimal_unit_price
               }
             } = AssetTracker.add_purchase(symbol, settle_date, quantity, unit_price)

      assert [
               {^symbol,
                [
                  %{
                    quantity: ^quantity,
                    settle_date: ~N[2023-05-05 10:00:00],
                    unit_price: ^decimal_unit_price
                  }
                ]}
             ] = :ets.lookup(:asset_tracker, symbol)
    end

    test "should return an error if pass a wrong datetime", %{params: params} do
      %{
        symbol: symbol,
        quantity: quantity,
        unit_price: unit_price
      } = params

      assert {:error, "Please put a correct settle_date datetime format, Ex: 2023-05-05T10:00:00"} =
               AssetTracker.add_purchase(symbol, "2023-05-05", quantity, unit_price)
    end
  end

  describe "add_sale/4" do
    setup do
      AssetTracker.new()

      AssetTracker.add_purchase("ASD", "2023-05-05T10:00:00", 10, 4)

      params = %{
        symbol: "ASD",
        sell_date: "2023-05-10T10:00:00",
        quantity: 5,
        unit_price: 10
      }

      %{params: params, purchase_unit_price: Decimal.new(4)}
    end

    test "should return the updated AssetTracker and the gain or loss", %{
      params: params,
      purchase_unit_price: purchase_unit_price
    } do
      %{
        symbol: symbol,
        sell_date: sell_date,
        quantity: quantity,
        unit_price: unit_price
      } = params

      gain_or_loss = Decimal.new("30")

      assert {%{
                "ASD" => [
                  %{
                    quantity: 5,
                    settle_date: ~N[2023-05-05 10:00:00],
                    unit_price: ^purchase_unit_price
                  }
                ]
              }, ^gain_or_loss} = AssetTracker.add_sale(symbol, sell_date, quantity, unit_price)
    end

    test "should return an error when pass a quantity greater that the purchase quantity", %{
      params: params
    } do
      %{
        symbol: symbol,
        sell_date: sell_date,
        unit_price: unit_price
      } = params

      assert {:error, "This asset does not have enough quantity for this sale"} =
               AssetTracker.add_sale(symbol, sell_date, 100, unit_price)
    end

    test "should return an error when the purchase does not exist", %{
      params: params
    } do
      %{
        sell_date: sell_date,
        quantity: quantity,
        unit_price: unit_price
      } = params

      assert {:error, "Asset was not found"} =
               AssetTracker.add_sale("BRD", sell_date, quantity, unit_price)
    end

    test "should return an error when pass a wrong sell_date", %{
      params: params
    } do
      %{
        symbol: symbol,
        quantity: quantity,
        unit_price: unit_price
      } = params

      assert {:error, "Please put a correct sell_date datetime format, Ex: 2023-05-05T10:00:00"} =
               AssetTracker.add_sale(symbol, "2023-05-05", quantity, unit_price)
    end
  end
end
