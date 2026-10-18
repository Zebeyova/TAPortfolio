# Shader 学习答疑记录

本文档记录目前从零编写 URP 风格化 Shader 过程中已经确认的概念、问题和处理方式，方便后续继续扩展 `StylizedLight.shader`。

## 项目背景

- Unity：2022.3.62f3c1
- 渲染管线：URP 14.0.12
- 当前学习 Shader：`Assets/Shaders/URPShaders/StylizedLight.shader`
- 目标：从基础光照开始，逐步建立自己的风格化渲染，而不是继续修复旧 ASE Shader。
- 旧 ASE Shader 保留作为参考，不直接替换。

## 旧 ASE Shader 在 URP 中颜色异常

把 Built-in Shader 的渲染类型改成 URP/Lit，只能解决一部分管线兼容问题。旧 Shader 仍然可能依赖 Built-in 的光照变量、阴影宏、Pass、纹理属性或颜色空间约定，所以材质可能显示为纯白、纯黑或颜色异常。

稳定的做法是重新建立自己的 URP Shader，先实现最小的基础光照，再逐步加入阴影、法线、附加光和其他效果。

## Cloud Shader 的定位

Cloud Shader 通常不是普通物体的基础 Lit Shader。它可能包含体积感、散射、透明混合、面向摄像机的效果、实例化或特殊深度处理，因此不能简单地当作普通材质迁移。

当前阶段不修复 Cloud Shader，先完成基础 Stylized Lit。这样可以避免在基础光照还没有验证时，同时处理云、水、草和植被的专用逻辑。

## 公共 HLSL 文件应该放什么

公共 HLSL 文件适合放所有材质都可能复用的内容：

- 光照计算函数
- Ramp 采样和色阶处理函数
- 法线转换函数
- Fresnel、雾、环境光等通用函数
- 统一的结构体或辅助函数

具体材质的参数通常仍由 Shader 自己声明，例如 `_BaseColor`、`_RampTex`、`_NormalMap`。C# 只负责传递运行时需要统一控制的值，例如风力、全局颜色或环境强度。

可以这样理解：公共 HLSL 是“计算方法”，材质 Shader 是“参数和使用方式”，C# 是“运行时控制器”。

## StylizedLight 当前基础流程

当前已经实现的主要流程是：

1. 采样 `_BaseMap`。
2. 乘以 `_BaseColor` 得到基础颜色。
3. 将模型法线转换到世界空间。
4. 通过 `SampleSH(normalWS)` 获取环境光。
5. 通过 `GetMainLight(...)` 获取主光。
6. 计算 `NdotL`，表示表面朝向主光的程度。
7. 用 `NdotL` 作为 Ramp 的横坐标。
8. 将 Ramp 结果应用到直接光，将环境光单独保留。
9. 使用 `AdditionalLight` 函数循环处理 URP 提供的点光源和聚光灯。

当前核心表达式是：

```hlsl
half NdotL = saturate(dot(normalWS, mainLight.direction));
half3 rampColor = SAMPLE_TEXTURE2D(
    _RampTex,
    sampler_RampTex,
    float2(NdotL, 0.5)
).rgb;

half3 finalCol = albedo.rgb * (rampColor * directLight + ambientLight);
```

## 附加光源的基本结构

附加光源指主方向光之外的点光源和聚光灯。它们不能共用主光的 `NdotL`，因为每一盏灯的方向、距离和衰减都不同。

基本流程是：

```hlsl
uint addLightCount = GetAdditionalLightsCount();

LIGHT_LOOP_BEGIN(addLightCount)
    Light additionalLight = GetAdditionalLight(lightIndex, positionWS);
    half additionalNdotL = saturate(dot(normalWS, additionalLight.direction));
    half3 additionalRampCol = SAMPLE_TEXTURE2D(
        _RampTex,
        sampler_RampTex,
        float2(additionalNdotL, 0.5)
    ).rgb;

    additionalLightCol +=
        additionalRampCol *
        additionalLight.color *
        additionalLight.distanceAttenuation *
        additionalLight.shadowAttenuation;
LIGHT_LOOP_END
```

可以把每次循环理解为“处理一盏灯”：

- `GetAdditionalLightsCount()`：取得当前物体附近、允许参与渲染的附加光数量。
- `GetAdditionalLight(...)`：取得当前编号的灯，包括方向、颜色、距离衰减和阴影衰减。
- `additionalNdotL`：计算表面是否朝向这一盏灯。
- `additionalRampCol`：使用这盏灯自己的受光强度采样 Ramp。
- `additionalLightCol +=`：把当前灯的结果累加到附加光总颜色。

最终颜色可以写成：

```hlsl
half3 finalCol = albedo.rgb *
    (rampCol * directLight + ambientLight + additionalLightCol);
```

附加光变体要单独声明，不能和主光阴影选项写在同一个五选一列表中：

```hlsl
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
#pragma multi_compile _ _ADDITIONAL_LIGHTS
#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
#pragma multi_compile_fragment _ _SHADOWS_SOFT
```

如果把 `_ADDITIONAL_LIGHTS` 直接放到主光阴影那一行，Unity 会把它当成同一组互斥选项，可能导致启用主光阴影时没有附加光变体。

## 附加光阴影不是另外手写一套算法

`GetAdditionalLight(...)` 会返回一个 `Light` 结构，其中已经包含：

```hlsl
additionalLight.distanceAttenuation
additionalLight.shadowAttenuation
```

因此附加光的阴影读取通常只需要使用：

```hlsl
additionalLight.shadowAttenuation
```

不需要在当前 Shader 中重新采样点光源阴影贴图。`UsePass` 负责让物体投射阴影，`GetAdditionalLight` 负责在接收物体上取得附加光的光照和阴影结果。

要看到真正的附加光投影阴影，需要同时确认：

- 当前 URP Asset 开启 Additional Light Shadows。
- 点光源或聚光灯的 Shadow Type 不是 None。
- 点光源、遮挡物和接收物体的 Layer/Culling Mask 正确。
- 当前使用的是支持附加光阴影的 URP Asset。

项目中当前配置的差异如下：

```text
URP-Performant.asset：附加光 Per Vertex，附加光阴影关闭
URP-Balanced.asset：附加光 Per Pixel，附加光阴影关闭
URP-HighFidelity.asset：附加光 Per Pixel，附加光阴影开启
```

所以如果当前运行时使用的是 Performant 或 Balanced，点光源仍然可以产生光照和距离衰减，但不会产生真正的附加光阴影。

## 如何判断普通 Forward 和 Forward+

在当前 Unity 2022.3 / URP 14 项目中，选中当前使用的 Renderer Data，在 Inspector 查看 `Rendering Mode`：

```text
Forward：普通 Forward
Forward+：Forward+
Deferred：Deferred
```

项目中的 Renderer 资产还可以从序列化字段判断：

```text
m_ClusteredRendering: 0
```

表示没有启用 Forward+ clustered rendering。当前 `URP-Performant-Renderer` 和 `URP-Balanced-Renderer` 都是普通 Forward。`Additional Lights = Per Pixel` 只表示附加光的计算频率，不等于 Forward+。

普通 Forward 下使用：

```hlsl
uint addLightCount = GetAdditionalLightsCount();
LIGHT_LOOP_BEGIN(addLightCount)
```

是合适的起点。只有切换到 Forward+ 后，才需要按 Forward+ 的光源遍历方式补充相应宏和逻辑。

## 点光源过近出现方形阴影

点光源离物体非常近时，方形或块状阴影通常来自点光源阴影贴图、Bias、Normal Bias、Near Plane 或阴影分辨率，而不是 Ramp 本身。

排查时可以临时去掉：

```hlsl
additionalLight.shadowAttenuation
```

只保留距离衰减：

```hlsl
additionalLightCol +=
    additionalRampCol *
    additionalLight.color *
    additionalLight.distanceAttenuation;
```

如果方形区域消失，说明问题在附加光阴影贴图设置；如果仍然存在，则继续检查 Ramp、法线贴图和色阶参数。

点光源阴影的检查顺序：

1. 暂时使用 Hard Shadows，区分阴影贴图问题和软阴影采样问题。
2. 适当调整点光源的 Bias、Normal Bias 和 Near Plane。
3. 将点光源稍微移离物体，避免几乎贴在表面上。
4. 提高 URP Asset 的 Additional Light Shadow Resolution。
5. 确认当前使用的是开启 `m_AdditionalLightShadowsSupported` 的 URP Asset。

## 为什么 Ramp 没有硬过渡

Ramp 的结果取决于 Ramp 图片本身。如果图片是连续渐变，采样结果也会连续变化；如果图片是几段纯色，采样结果才会形成明显色阶。

当前 Ramp 图大致是三段颜色：

- 左侧：蓝灰色
- 中间：灰绿色
- 右侧：暖白色

如果需要硬边，建议在 Unity 导入设置中使用：

- `Filter Mode`：`Point`
- `Wrap Mode`：`Clamp`
- 关闭 Mipmap
- 关闭或降低压缩，避免颜色边界被压缩污染

采样坐标必须写成二维向量：

```hlsl
float2(NdotL, 0.5)
```

不能写成：

```hlsl
(NdotL, 0.5)
```

后者不是明确的 HLSL 二维 UV 写法。

## Ramp 应该使用彩色还是黑白

两种用途都可以，但含义不同。

### 黑白 Ramp

黑白 Ramp 主要控制光照强度：

```text
深灰 → 中灰 → 白
```

物体最终颜色主要由 `_BaseMap` 和 `_BaseColor` 决定。这种方式比较容易控制，也适合先验证光照是否正确。

### 彩色 Ramp

彩色 Ramp 同时控制明暗和色相：

```text
蓝灰 → 灰绿 → 暖白
```

这种方式可以直接形成风格化调色板，但如果直接和绿色材质颜色相乘，阴影可能变得很暗或颜色偏移明显。

## 为什么环境光要和 Ramp 分开

如果写成：

```hlsl
albedo.rgb * (rampColor * (directLight + ambientLight))
```

那么环境光也会被 Ramp 的暗色区域压低。阴影面可能变成很深的颜色。

通常更容易控制的写法是：

```hlsl
albedo.rgb * (rampColor * directLight + ambientLight)
```

这里 Ramp 只控制主光，环境光作为基础填充保留下来。

## Shader 变体是什么

Shader 变体是同一份 Shader 根据不同功能开关编译出来的不同版本。

例如：

```hlsl
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
#pragma multi_compile_fragment _ _SHADOWS_SOFT
```

这些指令让 Unity 为不同主光阴影模式和软阴影模式准备对应版本。

`multi_compile` 的每一行都会增加选项组合。上面两行概念上可能产生 `4 × 2 = 8` 种组合。

它们不是 8 个 Shader 文件，而是 Unity 根据当前 URP 设置和材质状态选择其中一个编译版本。

需要注意拼写：

```hlsl
#pragma multi_compile
```

不能写成：

```hlsl
#pragma mulit_compile
```

## 阴影接收与阴影投射

阴影接收和阴影投射是两个不同的过程：

- 阴影接收：当前物体判断自己是否被主光遮挡。
- 阴影投射：当前物体把自己的形状写入阴影贴图，让其他物体看到它造成的阴影。

当前 `UniversalForward` 中通过：

```hlsl
Light mainLight = GetMainLight(input.shadowCoord);
```

读取主光阴影。

如果不想自己编写 `ShadowCaster` Pass，可以复用 URP/Lit 的 Pass：

```hlsl
UsePass "Universal Render Pipeline/Lit/ShadowCaster"
```

`UsePass` 是把另一个 Shader 的指定 Pass 加入当前 Shader。

`Fallback` 的作用不同：它是在当前 Shader 没有可用 SubShader 时使用另一个 Shader，不能等同于自动补充一个 `ShadowCaster` Pass。

如果以后加入 Alpha Clip 或顶点变形，需要确认复用的 `ShadowCaster` 是否也使用了相同的裁剪和顶点变形，否则显示形状与阴影形状可能不一致。

## 法线贴图转换为什么使用 TBN

法线贴图中的法线是切线空间法线，光照计算需要世界空间法线。因此要用切线、副切线和表面法线组成的 TBN 基底，把 `normalTS` 转换为 `normalWS`：

```hlsl
half3 normalWS = normalize(
    input.tangentWS * normalTS.x +
    input.bitangentWS * normalTS.y +
    input.normalWS * normalTS.z
);
```

含义是：

```text
世界空间法线
= 切线方向   × 法线贴图 X
+ 副切线方向 × 法线贴图 Y
+ 表面法线   × 法线贴图 Z
```

法线贴图的 RGB 通道通常表示：

- R：沿切线方向的偏移
- G：沿副切线方向的偏移
- B：沿表面法线方向的偏移

如果法线贴图是默认平面法线 `float3(0, 0, 1)`，公式会还原原来的表面法线。如果法线贴图让法线向切线方向偏移，转换后的世界空间法线也会随之改变，`NdotL` 和 Ramp 色阶就会产生细节变化。

最后使用 `normalize`，是因为三个方向相加后长度不一定仍为 1，而点积光照通常需要单位方向向量。

## 当前文件中暂时保留但尚未使用的参数

目前以下参数已经声明，但还没有参与最终颜色计算：

```hlsl
_NormalMap
_ShadowThreshlod
_ShadowSoftness
_ShadowTint
```

`_NormalMap` 下一步用于接入 TBN 法线转换。后三个参数可以在以后选择使用 `smoothstep` 做可调节的软色阶，或者暂时保留作为后续实验参数。

## 推荐的后续实现顺序

1. 验证附加光循环在点光源和聚光灯下的颜色、距离衰减和 Ramp 分区。
2. 根据实际使用的 URP Asset 决定是否启用附加光阴影。
3. 解决点光源近距离阴影贴图的 Bias、Near Plane 和分辨率问题。
4. 再决定是否使用 `_ShadowThreshold`、`_ShadowSoftness` 和 `_ShadowTint` 做额外的阴影染色。
5. 最后再考虑 Fresnel、雾、Lightmap、Meta、DepthOnly 和其他专用 Shader 功能。
