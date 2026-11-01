//  Copyright (c) 2026-present amlovey
// 
using System;
using System.Linq;
using OmniShader.Common.UI;
using UnityEngine;
using UnityEngine.UIElements;
using UnityEditor;

namespace OmniShader.Editor
{
    public class ExploreContent : ContentControl
    {
        private OmniShaderEditorState state;
        private ListView shaderList;
        private Container titleContainer;
        private DropdownTextButton filterDropdown;
        private ListView materialList;
        private TextField searchTextField;

        public ExploreContent(string title) : base(NaviMenus.EXPLORE, title)
        {
            var refreshButton = new TextButton("Refresh");
            refreshButton.tooltip = "Refresh page data.";
            refreshButton.style.position = Position.Absolute;
            refreshButton.style.height = 28;
            refreshButton.style.width = 60;
            refreshButton.style.top = 8;
            refreshButton.style.right = 0;
            refreshButton.OnClick += () =>
            {
                this.state.shaders = AssetsExplorerHelper
                      .GetAllShaderNames()
                      .Select(it => AssetsExplorerHelper.GetShaderByName(it))
                      .OrderBy(it => it.Name)
                      .ToList();

                this.state.materials = AssetsExplorerHelper
                        .GetAllMaterialGuids(StorageType.All)
                        .Select(it => AssetsExplorerHelper.GetMaterial(it))
                        .OrderBy(it => it.Name)
                        .ToList();

                UpdateItemsBaseOnFilter();
                UpdateMaterialsBaseOnSelection();
            };

            this.Add(refreshButton);
        }

        private void BuildTitleAndToolbar()
        {
            titleContainer = new Container(0, 52, 0, 0);
            titleContainer.style.height = 36;

            var title = new Label("Shaders:");
            title.style.fontSize = 21;
            title.style.unityTextAlign = TextAnchor.LowerLeft;
            title.style.position = Position.Absolute;
            title.style.bottom = 0;
            titleContainer.Add(title);

            var clearButton = new IconButton(Icons.Clear);
            clearButton.style.position = Position.Absolute;
            clearButton.style.backgroundColor = ColorHelper.Parse("#00000000");
            clearButton.style.right = 36;
            clearButton.style.bottom = 7;
            clearButton.style.width = 16;
            clearButton.style.height = 16;
            clearButton.style.visibility = state.shaderSearchName.Length > 0 ? Visibility.Visible : Visibility.Hidden;
            clearButton.OnClick = () =>
            {
                searchTextField.value = string.Empty;
                state.shaderSearchName = string.Empty;
                UpdateItemsBaseOnFilter();
            };

            searchTextField = new TextField();
            searchTextField.style.height = 30;
            searchTextField.style.width = 184;
            searchTextField.style.position = Position.Absolute;
            searchTextField.style.bottom = -1;
            searchTextField.style.right = 25;
            searchTextField.SetValueWithoutNotify(state.shaderSearchName);
            searchTextField.RegisterValueChangedCallback(evt =>
            {
                clearButton.style.visibility = searchTextField.value.Length > 0 ? Visibility.Visible : Visibility.Hidden;

                var text = searchTextField.value;
                if (text != state.shaderSearchName)
                {
                    state.shaderSearchName = text;
                    UpdateItemsBaseOnFilter();
                    UpdateMaterialsBaseOnSelection();
                }
            });

            var searchButton = new IconButton(Icons.Search);
            searchButton.style.position = Position.Absolute;
            searchButton.style.right = 0;
            searchButton.style.width = 28;
            searchButton.style.height = 28;
            searchButton.style.bottom = 1;
            searchButton.OnClick = () =>
            {
                var text = searchTextField.value;
                if (text != state.shaderSearchName)
                {
                    state.shaderSearchName = text;
                    UpdateItemsBaseOnFilter();
                }
            };

            var selectionButton = new TextButton("Ping");
            selectionButton.tooltip = "Ping selected shaders in Project window";
            selectionButton.style.position = Position.Absolute;
            selectionButton.style.width = 56;
            selectionButton.style.right = 324;
            selectionButton.style.height = 28;
            selectionButton.style.bottom = 0;

            selectionButton.OnClick = () =>
            {
                Selection.objects = shaderList.selectedItems
                    .Select(it => it as OSShader)
                    .ToList()
                    .Select(it => it.GetShaderObject())
                    .ToArray();
            };


            titleContainer.Add(selectionButton);
            titleContainer.Add(searchButton);
            titleContainer.Add(searchTextField);
            titleContainer.Add(clearButton);
            this.Add(titleContainer);
        }

        private void RenderFilterDropDown()
        {
            var allMenu = "All";
            var inPojectMenu = "In Project";
            var inPackagesMenu = "In Packages";
            var hiddenMenu = "Hidden";
            var builtinMenu = "Builtin";
            var options = new string[] { allMenu, inPojectMenu, inPackagesMenu, hiddenMenu, builtinMenu };

            filterDropdown = new DropdownTextButton(options[state.shaderFilterIndex]);
            filterDropdown.style.width = 100;
            filterDropdown.style.position = Position.Absolute;
            filterDropdown.style.bottom = 0;
            filterDropdown.style.right = 216;

            for (int i = 0; i < options.Length; i++)
            {
                var option = options[i];
                var index = i;
                filterDropdown.menu.AppendAction(option,
                act =>
                {
                    state.shaderFilterIndex = index;
                    filterDropdown.SetText(option);
                    UpdateItemsBaseOnFilter();
                    UpdateMaterialsBaseOnSelection();
                }, DropdownMenuAction.Status.Normal);
            }

            titleContainer.Add(filterDropdown);
        }

        public void BuildShaderListContent()
        {
            var shaderListContent = new Container(0, 92, 0, 0);
            shaderListContent.style.height = 300;
            shaderListContent.style.backgroundColor = ColorHelper.Parse(Theme.Current.MenuBackground);
            this.Add(shaderListContent);

            var header = new ExporeListHeader();
            header.style.height = 28;
            header.style.position = Position.Absolute;
            header.style.left = 0;
            header.style.top = 0;
            header.style.right = 0;
            header.style.bottom = 0;
            shaderListContent.Add(header);

            shaderList = new ListView
            {
                fixedItemHeight = 28,
                makeItem = CreateShaderListItem,
                bindItem = UpdateShaderListItem,
                selectionType = SelectionType.Multiple,
            };

#if UNITY_6000_0_OR_NEWER
            shaderList.itemsChosen += (selectedItems) =>
            {
                Selection.objects = selectedItems
                    .Select(it => it as OSShader)
                    .ToList()
                    .Select(it => it.GetShaderObject())
                    .ToArray();
            };
#else
            shaderList.onItemsChosen += (selectedItems) =>
            {
                Selection.objects = selectedItems
                    .Select(it => it as OSShader)
                    .ToList()
                    .Select(it => it.GetShaderObject())
                    .ToArray();
            };
#endif
            shaderList.Rebuild();

            shaderList.style.position = Position.Absolute;
            shaderList.style.left = 0;
            shaderList.style.top = 28;
            shaderList.style.right = 0;
            shaderList.style.bottom = 0;
            shaderList.style.backgroundColor = ColorHelper.Parse(Theme.Current.Background);

#if UNITY_6000_0_OR_NEWER
            shaderList.selectedIndicesChanged += indexes =>
#else
            shaderList.onSelectedIndicesChange += indexes =>

#endif
            {
                UpdateMaterialsBaseOnSelection();
            };

            shaderListContent.Add(shaderList);
        }

        private void UpdateShaderListItem(VisualElement item, int index)
        {
            var row = item as ExporeListRow;
            row.style.unityTextAlign = TextAnchor.MiddleLeft;
            row.SetPadding(0, 8);

            var shader = shaderList.itemsSource[index] as OSShader;
            if (shader != null)
            {
                row.tooltip = shader.Path;
                row.SetData(index + 1, shader);
            }
        }

        private VisualElement CreateShaderListItem()
        {
            return new ExporeListRow();
        }

        private void BuildReferenceTitleContainer(Container parent)
        {
            var titleContainer = new Container(0, 0, 0, 0);
            titleContainer.style.height = 36;
            titleContainer.style.backgroundColor = ColorHelper.Parse(Theme.Current.StatusBarBackround);

            var referLabel = new Label("Referenced By Materials:");
            referLabel.style.fontSize = 21;
            referLabel.style.marginLeft = 4;
            referLabel.style.marginTop = 6;
            titleContainer.Add(referLabel);

            var selectionButton = new TextButton("Ping");
            selectionButton.tooltip = "Ping selected materials in Project window";
            selectionButton.style.position = Position.Absolute;
            selectionButton.style.width = 56;
            selectionButton.style.right = 4;
            selectionButton.style.height = 24;
            selectionButton.style.bottom = 6;

            selectionButton.OnClick = () =>
            {
                Selection.objects = materialList.selectedItems
                    .Select(it => it as OSMaterial)
                    .ToList()
                    .Select(it => it.GetMaterialObject())
                    .ToArray();
            };

            titleContainer.Add(selectionButton);

            parent.Add(titleContainer);
        }

        private void BuildReferencePanel()
        {
            var referencePanel = new Container(0, 393, 0, 0);
            BuildReferenceTitleContainer(referencePanel);

            materialList = new ListView
            {
                fixedItemHeight = 28,
                makeItem = CreateMaterialListItem,
                bindItem = UpdateMaterialListItem,
                selectionType = SelectionType.Multiple,
            };

            materialList.style.position = Position.Absolute;
            materialList.style.backgroundColor = ColorHelper.Parse(Theme.Current.Background);
            materialList.style.left = 0;
            materialList.style.top = 36;
            materialList.style.right = 0;
            materialList.style.bottom = 0;

            referencePanel.style.backgroundColor = ColorHelper.Parse(Theme.Current.MenuBackground);
            referencePanel.Add(materialList);

#if UNITY_6000_0_OR_NEWER
            materialList.itemsChosen += (selectedItems) =>
            {
                Selection.objects = selectedItems
                    .Select(it => it as OSMaterial)
                    .ToList()
                    .Select(it => it.GetMaterialObject())
                    .ToArray();
            };
#else
            materialList.onItemsChosen += (selectedItems) =>
            {
                Selection.objects = selectedItems
                    .Select(it => it as OSMaterial)
                    .ToList()
                    .Select(it => it.GetMaterialObject())
                    .ToArray();
            };
#endif
            materialList.Rebuild();

            this.Add(referencePanel);
        }

        private void UpdateMaterialListItem(VisualElement element, int index)
        {
            var row = element as MaterialListRow;
            row.style.unityTextAlign = TextAnchor.MiddleLeft;
            row.SetPadding(0, 8);

            var material = materialList.itemsSource[index] as OSMaterial;
            if (material != null)
            {
                row.tooltip = material.Path;
                row.SetData(index + 1, material);
            }
        }

        private VisualElement CreateMaterialListItem()
        {
            return new MaterialListRow();
        }

        public void SetState(OmniShaderEditorState state)
        {
            this.state = state;

            BuildTitleAndToolbar();
            BuildShaderListContent();
            BuildReferencePanel();
            RenderFilterDropDown();

            if (this.state != null)
            {
                if (this.state.shaders == null)
                {
                    this.state.shaders = AssetsExplorerHelper
                        .GetAllShaderNames()
                        .Select(it => AssetsExplorerHelper.GetShaderByName(it))
                        .OrderBy(it => it.Name)
                        .ToList();
                }

                if (this.state.materials == null)
                {
                    this.state.materials = AssetsExplorerHelper
                        .GetAllMaterialGuids(StorageType.All)
                        .Select(it => AssetsExplorerHelper.GetMaterial(it))
                        .OrderBy(it => it.Name)
                        .ToList();
                }
            }

            UpdateItemsBaseOnFilter();
        }

        private void UpdateItemsBaseOnFilter()
        {
            shaderList.itemsSource = state.shaders.Where(it =>
            {
                switch (state.shaderFilterIndex)
                {
                    case 0:
                        return true;
                    case 1:
                        return AssetsExplorerHelper.IsMatchStorageType(it.Path, StorageType.InAssets);
                    case 2:
                        return AssetsExplorerHelper.IsMatchStorageType(it.Path, StorageType.InPackages);
                    case 3:
                        return it.Name.StartsWith("Hidden/");
                    case 4:
                        return it.Guid.StartsWith("00000000");
                    default:
                        return false;
                }
            }).Where(it =>
            {
                if (!string.IsNullOrEmpty(state.shaderSearchName))
                {
                    return it.Name.IndexOf(state.shaderSearchName, StringComparison.OrdinalIgnoreCase) >= 0;
                }

                return true;
            }).OrderBy(it => it.Name).ToList();
        }

        private void UpdateMaterialsBaseOnSelection()
        {
            var materials = state.materials.Where(it =>
                {
                    return shaderList.selectedIndices.Any(idx =>
                    {
                        var shader = shaderList.itemsSource[idx] as OSShader;
                        return it.ShaderName == shader.Name;
                    });
                });

                materialList.itemsSource = materials.ToList();
                materialList.selectedIndex = -1;
        }
    }

    public class MaterialListRow : VisualElement
    {
        private Label indexLabel;
        private Label nameLabel;
        private Image iconImage;

        public MaterialListRow()
        {
            this.style.display = DisplayStyle.Flex;
            this.style.flexDirection = FlexDirection.Row;

            indexLabel = new Label();
            indexLabel.style.unityTextAlign = TextAnchor.MiddleLeft;
            indexLabel.style.width = 60;
            Add(indexLabel);

            iconImage = new Image();
            iconImage.style.width = 16;
            iconImage.style.height = 16;
            iconImage.style.marginTop = 5;
            iconImage.style.marginRight = 4;
            this.Add(iconImage);

            nameLabel = new Label();
            nameLabel.style.unityTextAlign = TextAnchor.MiddleLeft;
            this.Add(nameLabel);
        }

        public void SetData(int index, OSMaterial material)
        {
            this.indexLabel.text = index.ToString();
            this.nameLabel.text = material.Name;

            var mat = material.GetMaterialObject();
            if (mat != null)
            {
                var tex = AssetPreview.GetMiniThumbnail(mat);
                iconImage.image = tex;
            }
        }
    }

    public class ExporeListRow : VisualElement
    {
        private Label indexLabel;
        private Label nameLabel;
        private Image iconImage;

        public ExporeListRow()
        {
            this.style.display = DisplayStyle.Flex;
            this.style.flexDirection = FlexDirection.Row;

            indexLabel = new Label();
            indexLabel.style.unityTextAlign = TextAnchor.MiddleLeft;
            indexLabel.style.width = 60;
            Add(indexLabel);

            iconImage = new Image();
            iconImage.style.width = 16;
            iconImage.style.height = 16;
            iconImage.style.marginTop = 5;
            iconImage.style.marginRight = 4;
            this.Add(iconImage);

            nameLabel = new Label();
            nameLabel.style.unityTextAlign = TextAnchor.MiddleLeft;
            this.Add(nameLabel);
        }

        public void SetData(int index, OSShader shader)
        {
            this.indexLabel.text = index.ToString();
            this.nameLabel.text = shader.Name;

            var obj = shader.GetShaderObject();
            if (obj != null)
            {
                var tex = AssetPreview.GetMiniThumbnail(obj);
                iconImage.image = tex;
            }
        }
    }

    public class ExporeListHeader : VisualElement
    {
        public ExporeListHeader()
        {
            this.style.display = DisplayStyle.Flex;
            this.style.flexDirection = FlexDirection.Row;
            this.style.paddingLeft = 8;
            this.style.backgroundColor = ColorHelper.Parse(Theme.Current.ListBoxHeaderBackground);

            var indexLabel = new Label("#");
            indexLabel.style.unityTextAlign = TextAnchor.MiddleLeft;
            indexLabel.style.width = 60;
            indexLabel.style.unityFontStyleAndWeight = FontStyle.Bold;
            Add(indexLabel);

            var nameLabel = new Label("Name");
            nameLabel.style.unityTextAlign = TextAnchor.MiddleLeft;
            nameLabel.style.unityFontStyleAndWeight = FontStyle.Bold;
            this.Add(nameLabel);
        }
    }
}