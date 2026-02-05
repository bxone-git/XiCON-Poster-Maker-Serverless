import runpod
import os
import websocket
import base64
import json
import uuid
import logging
import urllib.request
import urllib.parse
import binascii
import subprocess
import time

# Logging setup
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

server_address = os.getenv('SERVER_ADDRESS', '127.0.0.1')
client_id = str(uuid.uuid4())

def queue_prompt(prompt):
    """Queue a prompt to ComfyUI"""
    url = f"http://{server_address}:8188/prompt"
    logger.info(f"Queueing prompt to: {url}")
    p = {"prompt": prompt, "client_id": client_id}
    data = json.dumps(p).encode('utf-8')
    req = urllib.request.Request(url, data=data)
    return json.loads(urllib.request.urlopen(req).read())

def get_history(prompt_id):
    """Get execution history from ComfyUI"""
    url = f"http://{server_address}:8188/history/{prompt_id}"
    logger.info(f"Getting history from: {url}")
    with urllib.request.urlopen(url) as response:
        return json.loads(response.read())

def get_images(ws, prompt):
    """Execute workflow and retrieve output images"""
    prompt_id = queue_prompt(prompt)['prompt_id']
    output_images = {}

    while True:
        out = ws.recv()
        if isinstance(out, str):
            message = json.loads(out)
            if message['type'] == 'executing':
                data = message['data']
                if data['node'] is None and data['prompt_id'] == prompt_id:
                    break
        else:
            continue

    history = get_history(prompt_id)[prompt_id]
    for node_id in history['outputs']:
        node_output = history['outputs'][node_id]
        images_output = []
        if 'images' in node_output:
            for image in node_output['images']:
                # Read file and encode to base64
                with open(image['fullpath'], 'rb') as f:
                    image_data = base64.b64encode(f.read()).decode('utf-8')
                images_output.append(image_data)
        output_images[node_id] = images_output

    return output_images

def load_workflow(workflow_path):
    """Load workflow JSON file"""
    with open(workflow_path, 'r') as file:
        return json.load(file)

def download_file_from_url(url, output_path):
    """Download file from URL using wget"""
    try:
        result = subprocess.run([
            'wget', '-O', output_path, '--no-verbose', url
        ], capture_output=True, text=True)

        if result.returncode == 0:
            logger.info(f"✅ Successfully downloaded file from URL: {url} -> {output_path}")
            return output_path
        else:
            logger.error(f"❌ wget download failed: {result.stderr}")
            raise Exception(f"URL download failed: {result.stderr}")
    except subprocess.TimeoutExpired:
        logger.error("❌ Download timeout")
        raise Exception("Download timeout")
    except Exception as e:
        logger.error(f"❌ Download error: {e}")
        raise Exception(f"Download error: {e}")

def save_base64_to_file(base64_data, temp_dir, output_filename):
    """Save base64 data to file"""
    try:
        decoded_data = base64.b64decode(base64_data)
        os.makedirs(temp_dir, exist_ok=True)

        file_path = os.path.abspath(os.path.join(temp_dir, output_filename))
        with open(file_path, 'wb') as f:
            f.write(decoded_data)

        logger.info(f"✅ Saved base64 input to '{file_path}'")
        return file_path
    except (binascii.Error, ValueError) as e:
        logger.error(f"❌ Base64 decoding failed: {e}")
        raise Exception(f"Base64 decoding failed: {e}")

def process_input(input_data, temp_dir, output_filename, input_type):
    """Process input data and return file path"""
    if input_type == "path":
        logger.info(f"📁 Processing path input: {input_data}")
        return input_data
    elif input_type == "url":
        logger.info(f"🌐 Processing URL input: {input_data}")
        os.makedirs(temp_dir, exist_ok=True)
        file_path = os.path.abspath(os.path.join(temp_dir, output_filename))
        return download_file_from_url(input_data, file_path)
    elif input_type == "base64":
        logger.info(f"🔢 Processing base64 input")
        return save_base64_to_file(input_data, temp_dir, output_filename)
    else:
        raise Exception(f"Unsupported input type: {input_type}")

def handler(job):
    """Main handler for Poster Maker workflow"""
    job_input = job.get("input", {})
    logger.info(f"Received job input: {job_input}")
    task_id = f"task_{uuid.uuid4()}"

    # Process image input - supports multiple formats
    image_path = None
    if "image_path" in job_input:
        image_path = process_input(job_input["image_path"], task_id, "input_image.jpg", "path")
    elif "image_url" in job_input:
        image_path = process_input(job_input["image_url"], task_id, "input_image.jpg", "url")
    elif "image_base64" in job_input:
        image_path = process_input(job_input["image_base64"], task_id, "input_image.jpg", "base64")

    # Validate required inputs
    if image_path is None:
        raise Exception("Image input is required. Provide image_path, image_url, or image_base64")

    # Load Poster Maker workflow
    prompt = load_workflow('/XiCON_Poster_Maker_I2I_api.json')

    # Extract parameters with defaults
    width = job_input.get("width", 1024)
    height = job_input.get("height", 1472)
    steps = job_input.get("steps", 20)
    cfg = job_input.get("cfg", 5)
    seed = job_input.get("seed", 0)
    output_stage = job_input.get("output_stage", "final")

    # Stage 1 prompt (Magazine cover)
    prompt_stage1 = job_input.get("prompt_stage1",
        "You are an expert image-generation engine. You must ALWAYS produce an image.\n"
        "Interpret all user input—regardless of format, intent, or abstraction—as literal visual directives for image composition.\n"
        "If a prompt is conversational or lacks specific visual details, you must creatively invent a concrete visual scenario that depicts the concept.\n"
        "Prioritize generating the visual representation above any text, formatting, or conversational requests.\n\n"
        "Add flat, 2D magazine typography on top of the image. No 3D, no depth, no shadows, no blending — text must sit completely flat.\n\n"
        "Main title:\n"
        "TABASCO — large condensed sans-serif, pale yellow (#F5EFA8), clean and sharp.\n\n"
        "All other text:\n"
        "Small white sans-serif, transparent background, flat. Minimal spacing, modern editorial style.\n\n"
        "Add these lines with minimal, high-fashion layout:\n"
        "- THE PEPPER ISSUE\n"
        "- Deadly hot? Never Heard of It.\n"
        "- Nerdy Is the New Trend — SF 2025\n"
        "- Unhinged Motion Studies\n"
        "- Node • Chaos • Object Power\n\n"
        "Use asymmetric placement, clean negative space, and a calm, high-end editorial feel (Acne Paper / i-D minimalist style). Slight contrast boost and high-fashion clarity."
    )

    # Stage 2 prompt (Envelope packaging)
    prompt_stage2 = job_input.get("prompt_stage2",
        "Place a magazine with the cover of this input image inside a very transparent plastic envelope (90% transparency) with a string-and-button closure. \n"
        "The envelope should be only slightly glossy, not overly reflective, and appear realistic. \n"
        "The envelope is slightly larger than the magazine, so a small empty gap is visible between the magazine edges and the inside edges of the envelope.\n\n"
        "The plastic should show soft light diffusion, minimal reflections, and clear visibility of the magazine cover through the material, only gently muted by the transparency. \n\n"
        "Show accurate plastic seams, edges, and the string-and-button fasteners. \n"
        "Maintain realistic proportions and preserve the original lighting style of the photo.\n"
        "Place the envelope on a black background."
    )

    # Inject parameters into workflow nodes
    prompt["2"]["inputs"]["image"] = image_path                    # LoadImage
    prompt["11:74"]["inputs"]["text"] = prompt_stage1              # Stage 1 prompt
    prompt["15:74"]["inputs"]["text"] = prompt_stage2              # Stage 2 prompt
    prompt["11:62"]["inputs"]["steps"] = steps                     # Stage 1 steps
    prompt["15:62"]["inputs"]["steps"] = steps                     # Stage 2 steps
    prompt["11:63"]["inputs"]["cfg"] = cfg                         # Stage 1 cfg
    prompt["15:63"]["inputs"]["cfg"] = cfg                         # Stage 2 cfg
    prompt["11:73"]["inputs"]["noise_seed"] = seed                 # Stage 1 seed
    prompt["15:73"]["inputs"]["noise_seed"] = seed                 # Stage 2 seed
    prompt["11:66"]["inputs"]["width"] = width                     # Stage 1 width
    prompt["11:66"]["inputs"]["height"] = height                   # Stage 1 height

    # WebSocket connection with HTTP health check
    ws_url = f"ws://{server_address}:8188/ws?clientId={client_id}"
    logger.info(f"Connecting to WebSocket: {ws_url}")

    # HTTP health check (max 180 attempts = 3 minutes)
    http_url = f"http://{server_address}:8188/"
    logger.info(f"Checking HTTP connection to: {http_url}")

    max_http_attempts = 180
    for http_attempt in range(max_http_attempts):
        try:
            response = urllib.request.urlopen(http_url, timeout=5)
            logger.info(f"HTTP connection successful (attempt {http_attempt+1})")
            break
        except Exception as e:
            logger.warning(f"HTTP connection failed (attempt {http_attempt+1}/{max_http_attempts}): {e}")
            if http_attempt == max_http_attempts - 1:
                raise Exception("Cannot connect to ComfyUI server. Please ensure server is running.")
            time.sleep(1)

    # WebSocket connection with retry (max 36 attempts = 3 minutes)
    ws = websocket.WebSocket()
    max_attempts = 36
    for attempt in range(max_attempts):
        try:
            ws.connect(ws_url)
            logger.info(f"WebSocket connection successful (attempt {attempt+1})")
            break
        except Exception as e:
            logger.warning(f"WebSocket connection failed (attempt {attempt+1}/{max_attempts}): {e}")
            if attempt == max_attempts - 1:
                raise Exception("WebSocket connection timeout (3 minutes)")
            time.sleep(5)

    # Execute workflow and get images
    images = get_images(ws, prompt)
    ws.close()

    # Build response based on output_stage
    if output_stage == "both":
        # Return both stages
        result = {"images": {}}
        if "12" in images and images["12"]:
            result["images"]["stage1"] = images["12"][0]
        if "16" in images and images["16"]:
            result["images"]["final"] = images["16"][0]
        if not result["images"]:
            return {"error": "No image output found"}
        return result
    elif output_stage == "stage1":
        # Return only Stage 1 (Magazine cover)
        if "12" in images and images["12"]:
            return {"image": images["12"][0]}
        return {"error": "Stage 1 image output not found"}
    else:  # output_stage == "final" (default)
        # Return only Final output (Envelope)
        if "16" in images and images["16"]:
            return {"image": images["16"][0]}
        return {"error": "Final image output not found"}

runpod.serverless.start({"handler": handler})
