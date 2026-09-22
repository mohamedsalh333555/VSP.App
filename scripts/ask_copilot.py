import urllib.request
import json
import time
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="Ask VSP Copilot directly as Player or Owner")
    parser.add_argument("--role", choices=["player", "owner"], default="player", help="Persona to ask as")
    parser.add_argument("--message", required=True, help="Message to send to Copilot")
    parser.add_argument("--conversation_id", default=None, help="Existing conversation ID if any")
    args = parser.parse_args()

    token_file = "test_owner_token.txt" if args.role == "owner" else "test_user_token.txt"
    try:
        with open(token_file, "r") as f:
            token = f.read().strip()
    except Exception as e:
        print(f"Error reading token file {token_file}: {e}", file=sys.stderr)
        sys.exit(1)

    url = "https://mktqkddbcddrxjxabdua.supabase.co/functions/v1/vsp_copilot"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    payload = {"message": args.message}
    if args.conversation_id:
        payload["conversation_id"] = args.conversation_id

    req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
    start = time.time()
    try:
        with urllib.request.urlopen(req, timeout=35) as resp:
            dur = time.time() - start
            data = json.loads(resp.read().decode("utf-8"))
            output = {
                "success": True,
                "role": args.role,
                "question": args.message,
                "status_code": resp.status,
                "latency_seconds": round(dur, 2),
                "conversation_id": data.get("conversation_id"),
                "bot_message": data.get("message"),
                "quick_replies": data.get("quick_replies", []),
                "action": data.get("action"),
                "stadiums_count": len(data.get("stadiums", [])) if data.get("stadiums") else 0,
                "raw_response": data,
            }
            print(json.dumps(output, ensure_ascii=False, indent=2))
    except urllib.error.HTTPError as e:
        dur = time.time() - start
        err_body = e.read().decode("utf-8")
        output = {
            "success": False,
            "role": args.role,
            "question": args.message,
            "status_code": e.code,
            "latency_seconds": round(dur, 2),
            "error": err_body,
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))
    except Exception as e:
        dur = time.time() - start
        output = {
            "success": False,
            "role": args.role,
            "question": args.message,
            "status_code": 500,
            "latency_seconds": round(dur, 2),
            "error": str(e),
        }
        print(json.dumps(output, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
