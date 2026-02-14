
const API_URL = 'http://localhost:5000/api';

async function testbackend() {
    try {
        console.log('1. Logging in...');
        const response = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username: 'faculty1', password: 'password123' })
        });

        if (!response.ok) {
            console.error('❌ Login failed:', response.status, response.statusText);
            const text = await response.text();
            console.error('Response:', text);
            return;
        }

        const data = await response.json();
        const token = data.token;
        console.log('✅ Login successful. Token:', token.substring(0, 20) + '...');

        console.log('\n2. Fetching classes...');
        const classesRes = await fetch(`${API_URL}/faculty/classes`, {
            headers: { 'Authorization': `Bearer ${token}` }
        });

        if (!classesRes.ok) {
            console.error('❌ Fetch classes failed:', classesRes.status, classesRes.statusText);
            const text = await classesRes.text();
            console.error('Response:', text);
            return;
        }

        const classesData = await classesRes.json();
        console.log('✅ Classes response:', JSON.stringify(classesData, null, 2));

    } catch (error) {
        console.error('❌ Test failed:', error);
    }
}

testbackend();
