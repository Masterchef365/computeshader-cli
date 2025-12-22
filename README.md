# OpenGL Compute Shader Pipeline

A Python-based OpenGL compute shader pipeline that automatically infers buffers from shader code and executes compute shaders in sequence. This tool provides an easy way to run and visualize compute shader simulations.

## Prerequisites

- Python 3.x
- OpenGL 4.3+ compatible graphics card
- [Task](https://taskfile.dev/) (optional, for using the Taskfile)

## Installation

### Using Task (Recommended)

```bash
# Install Task runner
go install github.com/go-task/task/v3/cmd/task@latest

# Install Python dependencies and run examples
task install
```

### Manual Installation

```bash
# Install Python dependencies
pip install -r requirements.txt
```

## Usage

### Using Task (Recommended)

The project includes a `Taskfile.yml` with convenient tasks for running examples:

#### Available Tasks

- **`task install`** - Install Python requirements from `requirements.txt`
- **`task life`** - Run Conway's Game of Life simulation
- **`task twofield`** - Run two-field wave simulation (1024x1024, 10 steps per frame)
- **`task wave`** - Run single wave simulation
- **`task example`** - Run built-in Conway's Game of Life example
- **`task all-examples`** - Run all examples sequentially

#### Examples

```bash
# Run a specific example
task life
task twofield
task wave

# Run all examples
task all-examples

# Install dependencies and run an example
task install && task life
```

### Manual Usage

You can also run examples directly with Python:

```bash
# Built-in Game of Life example
python main.py --example

# Custom compute shaders
python main.py --compute examples/life/0_init.glsl examples/life/1_life.glsl
python main.py --compute examples/wave/wave.glsl --fragment examples/wave/nice.frag
python main.py --compute examples/twofield/twofield.glsl --steps 10 --fragment examples/twofield/nice.frag --width 1024 --height 1024
```

#### Command Line Options

- `--compute SHADER [SHADER ...]` - Compute shader files (executed in order)
- `--fragment SHADER` - Optional fragment shader for rendering
- `--width WIDTH` - Buffer width (default: 512)
- `--height HEIGHT` - Buffer height (default: 512)
- `--steps STEPS` - Compute steps per frame (default: 1)
- `--example` - Run built-in Conway's Game of Life

## Examples

### Conway's Game of Life
A classic cellular automaton simulation using compute shaders.

```bash
task life
# or
python main.py --compute examples/life/0_init.glsl examples/life/1_life.glsl
```

### Wave Simulation
Real-time wave equation simulation with obstacles and boundaries.

```bash
task wave
# or
python main.py --compute examples/wave/wave.glsl --fragment examples/wave/nice.frag
```

### Two-Field Simulation
Coupled wave equations simulation with interaction between two wave fields.

```bash
task twofield
# or
python main.py --compute examples/twofield/twofield.glsl --steps 10 --fragment examples/twofield/nice.frag --width 1024 --height 1024
```

## Architecture

The pipeline automatically:
1. Parses GLSL shader code to detect buffer declarations
2. Creates appropriate OpenGL textures for each buffer
3. Compiles and links compute/fragment shaders
4. Executes compute shaders in sequence
5. Renders results to screen using fragment shaders

### Buffer Detection

Buffers are detected using regex patterns on layout declarations:
```glsl
layout(rgba32f, binding = 0) uniform image2D buffer_name;
```

### Shader Execution Order

Compute shaders are executed in the order specified on the command line. Each shader can read from and write to image buffers using `imageLoad()` and `imageStore()`.

## Development

### Adding New Examples

1. Create a directory under `examples/`
2. Add your `.glsl` compute shaders
3. Optionally add a `.frag` fragment shader for custom rendering
4. Add a task to `Taskfile.yml` if desired

### Shader Requirements

- Use `#version 430` or higher
- Declare uniform buffers with `layout(rgba32f, binding = N) uniform image2D name;`
- Use `gl_GlobalInvocationID` for compute shader thread coordinates
- Access frame number via `uniform int frame;`
- Access resolution via `uniform vec2 resolution;`

## Troubleshooting

### Shader Compilation Errors

- Ensure your GLSL syntax is correct
- Check that buffer bindings don't conflict
- Verify OpenGL 4.3+ support
- Make sure `image2D` uniforms are not passed as function parameters (not supported in GLSL)

### Missing Dependencies

```bash
task install
# or
pip install -r requirements.txt
```

### Task Not Found

Install Task runner:
```bash
go install github.com/go-task/task/v3/cmd/task@latest
```