defmodule DialectPocket.RegionsTest do
  use DialectPocket.DataCase, async: true

  alias DialectPocket.Regions
  alias DialectPocket.Regions.Region

  defp create!(attrs), do: attrs |> Regions.create_region() |> then(fn {:ok, r} -> r end)

  describe "create_region/1" do
    test "creates a region with a valid path" do
      assert {:ok, %Region{} = r} =
               Regions.create_region(%{name: "日本", level: :country, path: "jp"})

      assert r.name == "日本"
      assert r.level == :country
    end

    test "rejects an invalid path format" do
      assert {:error, changeset} =
               Regions.create_region(%{name: "x", level: :area, path: "JP.Bad Path"})

      assert %{path: [_]} = errors_on(changeset)
    end

    test "rejects missing required fields" do
      assert {:error, changeset} = Regions.create_region(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:level]
      assert errors[:path]
    end

    test "enforces unique path" do
      create!(%{name: "日本", level: :country, path: "jp"})

      assert {:error, changeset} =
               Regions.create_region(%{name: "dup", level: :country, path: "jp"})

      assert %{path: [_]} = errors_on(changeset)
    end
  end

  describe "tree queries" do
    setup do
      jp = create!(%{name: "日本", level: :country, path: "jp"})
      aomori = create!(%{name: "青森県", level: :prefecture, path: "jp.aomori", parent_id: jp.id})

      tsugaru =
        create!(%{name: "津軽", level: :area, path: "jp.aomori.tsugaru", parent_id: aomori.id})

      nanbu = create!(%{name: "南部", level: :area, path: "jp.aomori.nanbu", parent_id: aomori.id})

      kagoshima =
        create!(%{name: "鹿児島県", level: :prefecture, path: "jp.kagoshima", parent_id: jp.id})

      %{jp: jp, aomori: aomori, tsugaru: tsugaru, nanbu: nanbu, kagoshima: kagoshima}
    end

    test "children/1 returns only direct children", %{
      jp: jp,
      aomori: aomori,
      kagoshima: kagoshima
    } do
      paths = jp |> Regions.children() |> Enum.map(& &1.path)
      assert Enum.sort(paths) == Enum.sort([aomori.path, kagoshima.path])
    end

    test "subtree/1 returns the node and all descendants, not siblings", %{
      aomori: aomori,
      tsugaru: tsugaru,
      nanbu: nanbu
    } do
      paths = aomori.path |> Regions.subtree() |> Enum.map(& &1.path)
      assert Enum.sort(paths) == Enum.sort([aomori.path, tsugaru.path, nanbu.path])
      # kagoshima (sibling subtree) must not leak in
      refute "jp.kagoshima" in paths
    end

    test "descendants/1 excludes the node itself", %{aomori: aomori} do
      paths = aomori |> Regions.descendants() |> Enum.map(& &1.path)
      refute aomori.path in paths
      assert "jp.aomori.tsugaru" in paths
      assert "jp.aomori.nanbu" in paths
    end

    test "subtree_ids/1 matches subtree/1", %{aomori: aomori} do
      ids = Regions.subtree_ids(aomori.path) |> Enum.sort()
      from_structs = aomori.path |> Regions.subtree() |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == from_structs
    end

    test "roots/0 returns only top-level regions", %{jp: jp} do
      assert [%Region{} = root] = Regions.roots()
      assert root.id == jp.id
    end

    test "subtree boundary: sibling sharing a prefix label does not leak", %{
      jp: jp,
      aomori: aomori
    } do
      # "jp.aomori2" shares the textual prefix "jp.aomori" but is NOT a descendant.
      _other = create!(%{name: "青森2", level: :prefecture, path: "jp.aomori2", parent_id: jp.id})
      paths = aomori.path |> Regions.subtree() |> Enum.map(& &1.path)
      refute "jp.aomori2" in paths
    end

    test "subtree of a leaf returns only itself", %{tsugaru: tsugaru} do
      assert [%Region{path: "jp.aomori.tsugaru"}] = Regions.subtree(tsugaru.path)
    end
  end

  describe "guards (H-1: LIKE wildcard injection)" do
    setup do
      jp = create!(%{name: "日本", level: :country, path: "jp"})
      create!(%{name: "青森県", level: :prefecture, path: "jp.aomori", parent_id: jp.id})
      :ok
    end

    test "subtree/1 rejects wildcard input instead of matching everything" do
      assert Regions.subtree("jp.aomori%") == []
      assert Regions.subtree("%") == []
      assert Regions.subtree("jp._omori") == []
      assert Regions.subtree("not a path!") == []
    end

    test "subtree_ids/1 rejects wildcard input" do
      assert Regions.subtree_ids("jp%") == []
      assert Regions.subtree_ids("_") == []
    end

    test "get_region_by_path/1 returns nil for invalid paths" do
      assert Regions.get_region_by_path("jp.%") == nil
      assert Regions.get_region_by_path("DROP") == nil
      assert %Region{} = Regions.get_region_by_path("jp.aomori")
    end
  end

  describe "parent/path consistency (H-4)" do
    setup do
      jp = create!(%{name: "日本", level: :country, path: "jp"})
      aomori = create!(%{name: "青森県", level: :prefecture, path: "jp.aomori", parent_id: jp.id})
      %{jp: jp, aomori: aomori}
    end

    test "accepts a path exactly one label below the parent", %{aomori: aomori} do
      assert {:ok, _} =
               Regions.create_region(%{
                 name: "津軽",
                 level: :area,
                 path: "jp.aomori.tsugaru",
                 parent_id: aomori.id
               })
    end

    test "rejects a path that is not under the parent path", %{jp: jp} do
      assert {:error, changeset} =
               Regions.create_region(%{
                 name: "迷子",
                 level: :area,
                 path: "jp.kagoshima.amami",
                 parent_id: jp.id
               })

      assert %{path: [_]} = errors_on(changeset)
    end

    test "rejects skipping a level (grandchild path under a grandparent)", %{jp: jp} do
      assert {:error, changeset} =
               Regions.create_region(%{
                 name: "飛び級",
                 level: :area,
                 path: "jp.aomori.tsugaru",
                 parent_id: jp.id
               })

      assert %{path: [_]} = errors_on(changeset)
    end
  end
end
