# Camera-Mapped Pixel PBR

该材质把一张按固定正交相机画面绘制的完整 2D 图，通过 `SCREEN_UV`
映射到多个真实 3D Mesh。Mesh 仍负责深度、遮挡、阴影和 SSAO，颜色与手绘
法线由整景贴图提供。

## 运行测试场景

运行：

`res://assets/shaders/camera_mapping/test/camera_mapping_test.tscn`

测试场景实例化现有 `res://node_3d.tscn`，不会修改原场景。控制器在运行时将
同一个 `camera_mapped_pixel_pbr.tres` 设置为所有 `MeshInstance3D` 的
`material_override`。

测试画幅是 `340 x 180`，与现有整景贴图一致。测试场景包含 DirectionalLight3D、
可移动的 OmniLight3D、SSAO 环境，以及用于四向灯光测试的 Marker3D。

## 替换贴图

打开 `camera_mapped_pixel_pbr.tres`，替换以下 Shader Parameter：

- `albedo_texture`：完整相机画面的颜色图。
- `normal_texture`：与颜色图逐像素对应的切线空间法线图。
- `material_texture`：可选，通道约定为 R Metallic、G Roughness、B AO。

不用 Material Map 时关闭 `use_material_map`。材质将使用
`default_metallic = 0.0`、`default_roughness = 0.8` 和 AO `1.0`。

贴图应使用 Lossless 压缩、禁用 Mipmap。Shader sampler 已强制使用最近邻采样
并禁用 Repeat。

## 保持相机与贴图对齐

相机必须保持 Orthogonal 投影，并固定以下参数：

- Global Transform
- Size
- Near / Far
- Keep Aspect
- H Offset / V Offset
- Viewport 宽高比

`CameraMappingController` 会缓存并恢复这些参数。使用控制器的
`projection_offset` 做小范围屏幕空间对齐，使用 `projection_scale` 修正画布比例。
这两个值会持续同步到共享材质。

## 判断 Normal Y 是否需要反转

将 OmniLight3D 依次移动到 `LightPositions` 下的 Left、Right、Up、Down。
观察 `scene_normal.png` 中对应方向的区域：

- 左右响应正确但上下相反时，开启 `invert_normal_y`。
- 轴整体错位时，检查法线图通道约定及 Shader 中的 TANGENT/BINORMAL 方向。

关闭 `use_normal_map` 后，所有接收面应使用统一的朝相机基础法线，不应因真实
Mesh 折面产生明显基础明暗断层。

## 固定相机限制

`SCREEN_UV` 表示当前屏幕位置，而不是世界位置或普通模型 UV。只有当相机旋转、
正交尺寸、Viewport 画幅和 Mesh 投影轮廓与绘制底稿保持一致时，完整 2D 图才能
与几何对齐。

第一版不支持相机移动或旋转、修改正交尺寸、运行时旋转接收物体、透视相机、
透明材质或多个不同机位。

## 调试视图

材质的 `debug_view`：

- `0` Final
- `1` Projection UV
- `2` Albedo
- `3` Normal
- `4` Metallic
- `5` Roughness
- `6` AO

## 为什么法线贴图看起来是绿色的

法线贴图不是最终显示颜色。它使用 RGB 编码每个像素的三维法线方向：

- R 表示切线空间左右方向。
- G 表示切线空间上下方向。
- B 表示朝向相机的方向。

`scene_normal.png` 中大面积偏绿或偏青的颜色是编码结果。材质正常运行时，它只会
写入 `NORMAL_MAP` 参与灯光计算；只有选择 `debug_view = Normal` 时才会作为颜色
直接显示。若上下受光方向相反，开启 `invert_normal_y`。

## 像素清晰度

测试项目关闭了 MSAA、屏幕空间抗锯齿和 TAA，并使用 `340 x 180` Viewport
以 4 倍整数缩放输出到 `1360 x 720` 窗口。`scene_diffuse.png` 与
`scene_normal.png` 使用 Lossless 导入并关闭 Mipmap。Shader sampler 使用最近邻
采样并禁止 Repeat。

Godot 4.6 会在启用纹理导入器的 Normal Map 标记时，自动将 3D 法线纹理切换为
VRAM 压缩并生成 Mipmap。为保持整景像素法线的原始 RGB，`scene_normal.png`
按普通 Lossless RGB 数据纹理导入，再由 shader 明确写入 `NORMAL_MAP`。

抗锯齿与 Mipmap 是不同功能：抗锯齿主要平滑几何边缘，Mipmap 会在纹理缩小时
选择低分辨率层级。像素整景贴图需要同时关闭抗锯齿和 Mipmap 才能保持清晰。

## 运行时灯光控制

- 按 `1` 选择 OmniLight3D，鼠标位置控制点光源在固定相机前方平面的位置。
- 按 `2` 选择并启用 DirectionalLight3D，鼠标位置控制方向光的 Yaw 与 Pitch。
- 左上角状态文字显示当前由鼠标控制的灯光。

`LightDirectionController` Inspector 中可调整 `omni_depth`、方向光 Yaw/Pitch 范围
以及总控制开关。灯光控制不会移动或解锁固定相机。

## 动态阴影稳定性

测试项目将 Directional 与 Omni 阴影过滤设为 Hard，并将灯光尺寸与阴影模糊设为
`0.0`。这样不会使用软阴影的抖动采样，适合关闭 TAA 的低分辨率像素画面。

动态灯光控制会先把鼠标位置取整到 `340 x 180` Viewport 的像素网格，再更新
OmniLight 位置或 DirectionalLight 方向。`pixel_step` 默认为 `1`；提高它可以获得
更稳定但更离散的灯光运动。HUD 会显示当前步进值与 Hard Shadows 状态。

SSAO 保持开启。若硬阴影启用后暗部仍有颗粒，可临时使用 Viewport 的
`DEBUG_DRAW_SSAO` 检查颗粒是否来自 SSAO，而不是实时阴影。硬阴影若出现表面自阴影
条纹，应只微调对应灯光的 `shadow_normal_bias`，避免无目的增大 Bias 导致阴影漂浮。
