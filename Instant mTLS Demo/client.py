from flask import Flask, render_template_string, request
import subprocess


app = Flask(__name__)

# HTML template with embedded CSS for styling
html_template = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Object Storage Consumer</title>
    <style>
        body {
            font-family: 'Roboto', sans-serif;
            margin: 0;
            padding: 0;
        }
        header {
            background-color: #333;
            color: white;
            text-align: center;
            padding: 40px 20px;
            font-size: 2.5em;
            margin-bottom: 20px;
        }
        header small{
            font-size:22px;
            opacity:0.5;
        }
        .container {
            margin: 20px;
        }
        .output-label {
            font-weight: bold;
            margin-bottom: 10px;
        }
        pre {
            background-color: #f4f4f4;
            padding: 10px;
            border: 1px solid #ccc;
            margin-bottom: 20px;
            font-size:20px;
        }
        .form-container {
            display: flex;
            flex-wrap: wrap;
            justify-content: space-between;
            gap: 20px;
            margin-bottom: 20px;
        }
        form {
            background-color: #F7F7F7;
            padding: 20px;
            border: 1px solid #E0E0E0;
            border-radius: 5px;
            flex: 1;
            min-width: 200px;
        }
        label, input, button {
            margin: 5px 10px;
        }
        input, button {
            padding: 10px;
            font-size:18px;
        }
    </style>
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;700&display=swap" rel="stylesheet">
</head>
<body>
    <header>Object Storage Consumer<br><small>( ext.instant.mtls.app )</small></header>
    <div class="container">
        <div class="output-label">Output</div>
        <pre id="display-text">{{ display_text }}</pre>
        <div class="form-container">
            <form method="POST">
                <label for="token">Auto-provisioning Token</label>
                <input type="text" id="token" name="token" required>
                <button type="submit" name="action" value="provision">Provision mTLS ID</button>
            </form>
            <form method="POST">
                <button type="submit" name="action" value="fetch_file">Fetch File</button>
            </form>
            <form method="POST">
                <button type="submit" name="action" value="rotate_certificate">Rotate Certificate</button>
            </form>
            <form method="POST">
                <button type="submit" name="action" value="run_diagnostics">mTLS ID Info</button>
            </form>
        </div>
    </div>
</body>
</html>
"""

def enroll(token):
    # Command to be executed
    command = [
        "/opt/identityplus/cli/identityplus",
        "-f", "/media/Work/Temp/IDP-Demo",
        "-d", "3Party",
        "enroll",
        token
    ]

    try:
        # Execute the command and capture the output
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        response = result.stdout
    except subprocess.CalledProcessError as e:
        # Handle errors in execution
        response = e.output
    
    return response

def renew():
    # Command to be executed
    command = [
        "/opt/identityplus/cli/identityplus",
        "-f", "/media/Work/Temp/IDP-Demo",
        "-d", "3Party",
        "renew"
    ]

    try:
        # Execute the command and capture the output
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        response = result.stdout
    except subprocess.CalledProcessError as e:
        # Handle errors in execution
        response = e.output
    
    return response

def fetch(url):
    # Command to be executed
    command = [
        "curl", url,
        "--cert", "/media/Work/Temp/IDP-Demo/3Party.cer",
        "--key", "/media/Work/Temp/IDP-Demo/3Party.key",
        "--cacert", "/media/Work/Temp/identity-plus-root.cer"
    ]

    try:
        # Execute the command and capture the output
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        response = result.stdout
    except subprocess.CalledProcessError as e:
        # Handle errors in execution
        response = e.output
    
    return response


@app.route("/", methods=["GET", "POST"])
def main_page():
    display_text = "Lorem, ipsum"

    if request.method == "POST":
        action = request.form.get("action")

        if action == "provision":
            token = request.form.get("token")
            enroll(token)
            display_text = "mTLS ID Provisioned:\n-----------\n" + fetch("https://minio-external.rbac.instant.mtls.app/identityplus/diagnose")

        elif action == "fetch_file":
            display_text = "Response from Object Storage Service:\n-----------\n" + fetch("https://minio-external.rbac.instant.mtls.app/private/content.txt")

        elif action == "run_diagnostics":
            display_text = "Certificate information:\n-----------\n" + fetch("https://minio-external.rbac.instant.mtls.app/identityplus/diagnose")

        elif action == "rotate_certificate":
            renew()
            display_text = "Certificate Rotated:\n-----------\n" + fetch("https://minio-external.rbac.instant.mtls.app/identityplus/diagnose")

    return render_template_string(html_template, display_text=display_text)

if __name__ == "__main__":
    app.run(debug=True)

