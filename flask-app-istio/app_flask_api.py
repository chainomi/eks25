
import os
import sys
import datetime

from flask import Flask, request
import requests
import json


app = Flask(__name__)



@app.route("/")
def home():
    return "hello world!"



if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
    

