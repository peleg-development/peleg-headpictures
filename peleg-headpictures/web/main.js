const PelegHeadPictures = {
    data() {
        return {
            displayedPicture: null,
            citizenId: null,
            isDisplaying: false
        };
    },
    methods: {
        toDataUrl(url, callback) {
            const xhr = new XMLHttpRequest();
            xhr.onload = function() {
                const reader = new FileReader();
                reader.onloadend = function() {
                    callback(reader.result);
                };
                reader.readAsDataURL(xhr.response);
            };
            xhr.open("GET", url);
            xhr.responseType = "blob";
            xhr.send();
        },
        
        compressImage(base64, quality, maxWidth, callback) {
            const img = new Image();
            img.onload = function() {
                const canvas = document.createElement('canvas');
                let width = img.width;
                let height = img.height;
                
                if (width > maxWidth) {
                    height = Math.round(height * maxWidth / width);
                    width = maxWidth;
                }
                
                canvas.width = width;
                canvas.height = height;
                
                const ctx = canvas.getContext('2d');
                ctx.drawImage(img, 0, 0, width, height);
                
                const compressedBase64 = canvas.toDataURL('image/jpeg', quality);
                callback(compressedBase64);
            };
            img.src = base64;
        },
        
        handleMessage(event) {
            const data = event.data;
            
            if (data.type === "convert_base64") {
                this.toDataUrl(data.img, (base64) => {
                    this.compressImage(base64, 0.6, 256, (compressedBase64) => {
                        fetch(`https://${GetParentResourceName()}/base64`, {
                            method: "POST",
                            headers: {"Content-Type": "application/json; charset=UTF-8"},
                            body: JSON.stringify({
                                base64: compressedBase64,
                                handle: data.handle,
                                handleId: data.handleId,
                                id: data.id
                            })
                        });
                    });
                });
            } else if (data.type === "display_picture") {
                this.displayedPicture = data.picture;
                this.citizenId = data.citizenId;
                this.isDisplaying = true;
                
                setTimeout(() => {
                    this.isDisplaying = false;
                }, 5000);
            }
        },
        
        hidePicture() {
            this.isDisplaying = false;
        },
        
        takePicture() {
            fetch(`https://${GetParentResourceName()}/peleg-headpictures:nui:takePicture`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.status === 'ok') {
                    console.log('Picture taken successfully');
                } else {
                    console.error('Failed to take picture');
                }
            })
            .catch(error => console.error('Error taking picture:', error));
        }
    },
    mounted() {
        window.addEventListener('message', this.handleMessage);
    },
    beforeUnmount() {
        window.removeEventListener('message', this.handleMessage);
    }
};

const app = Vue.createApp(PelegHeadPictures);
app.mount('#app');