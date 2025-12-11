import classNames from 'classnames';
import PropTypes from 'prop-types';
import React from 'react';
import ReactDOM from 'react-dom';
import {connect} from 'react-redux';
import {compose} from 'redux';

import Box from '../components/box/box.jsx';
import GUI from '../containers/gui.jsx';
import HashParserHOC from '../lib/hash-parser-hoc.jsx';
import AppStateHOC from '../lib/app-state-hoc.jsx';

import {setPlayer} from '../reducers/mode';

if (process.env.NODE_ENV === 'production' && typeof window === 'object') {
    // Warn before navigating away
    window.onbeforeunload = () => true;
}

import styles from './player.css';

const Player = ({isPlayerOnly, onSeeInside, projectId, vm}) => {
    // Expose VM globally for Kiosk control
    if (vm && typeof window !== 'undefined') {
        window.vm = vm;
    }
    
    return (
        <Box className={classNames(isPlayerOnly ? styles.stageOnly : styles.editor)}>
            {isPlayerOnly && <button onClick={onSeeInside}>{'See inside'}</button>}
            <GUI
                canEditTitle
                enableCommunity
                isPlayerOnly={isPlayerOnly}
                projectId={projectId}
            />
        </Box>
    );
};

Player.propTypes = {
    isPlayerOnly: PropTypes.bool,
    onSeeInside: PropTypes.func,
    projectId: PropTypes.string,
    vm: PropTypes.object
};

const mapStateToProps = state => ({
    isPlayerOnly: state.scratchGui.mode.isPlayerOnly,
    vm: state.scratchGui.vm
});

const mapDispatchToProps = dispatch => ({
    onSeeInside: () => dispatch(setPlayer(false))
});

const ConnectedPlayer = connect(
    mapStateToProps,
    mapDispatchToProps
)(Player);

// note that redux's 'compose' function is just being used as a general utility to make
// the hierarchy of HOC constructor calls clearer here; it has nothing to do with redux's
// ability to compose reducers.
const WrappedPlayer = compose(
    AppStateHOC,
    HashParserHOC
)(ConnectedPlayer);

const appTarget = document.createElement('div');
document.body.appendChild(appTarget);

ReactDOM.render(<WrappedPlayer isPlayerOnly />, appTarget);

// ============================================
// SIDEKICK Kiosk Control
// Load projects via URL parameter and respond to postMessage
// ============================================

// Check for project URL parameter on load
const urlParams = new URLSearchParams(window.location.search);
const projectUrl = urlParams.get('project');

if (projectUrl) {
    console.log('[Kiosk] Loading project from URL:', projectUrl);
    
    // Wait for VM to be ready, then load project
    const checkAndLoad = setInterval(() => {
        if (window.vm) {
            clearInterval(checkAndLoad);
            console.log('[Kiosk] VM ready, fetching project...');
            
            fetch(projectUrl)
                .then(response => {
                    if (!response.ok) throw new Error(`HTTP ${response.status}`);
                    return response.arrayBuffer();
                })
                .then(projectData => {
                    console.log('[Kiosk] Project fetched, loading into VM...');
                    return window.vm.loadProject(projectData);
                })
                .then(() => {
                    console.log('[Kiosk] Project loaded successfully!');
                    // Notify parent window
                    if (window.parent !== window) {
                        window.parent.postMessage({type: 'projectLoaded', success: true}, '*');
                    }
                })
                .catch(error => {
                    console.error('[Kiosk] Failed to load project:', error);
                    if (window.parent !== window) {
                        window.parent.postMessage({type: 'projectLoaded', success: false, error: error.message}, '*');
                    }
                });
        }
    }, 100);
    
    // Timeout after 30 seconds
    setTimeout(() => {
        if (!window.vm) {
            console.error('[Kiosk] Timeout waiting for VM');
        }
    }, 30000);
}

// Listen for postMessage commands from parent (Kiosk)
window.addEventListener('message', event => {
    const {type, data} = event.data || {};
    
    if (!window.vm) {
        console.log('[Kiosk] VM not ready for command:', type);
        return;
    }
    
    switch (type) {
        case 'loadProject':
            // data should be ArrayBuffer of .sb3 file
            console.log('[Kiosk] Loading project via postMessage...');
            window.vm.loadProject(data)
                .then(() => {
                    console.log('[Kiosk] Project loaded via postMessage');
                    if (event.source) {
                        event.source.postMessage({type: 'projectLoaded', success: true}, '*');
                    }
                })
                .catch(err => {
                    console.error('[Kiosk] Load error:', err);
                    if (event.source) {
                        event.source.postMessage({type: 'projectLoaded', success: false, error: err.message}, '*');
                    }
                });
            break;
            
        case 'greenFlag':
            console.log('[Kiosk] Starting project (green flag)');
            // Stelle sicher dass die VM läuft bevor greenFlag
            if (!window.vm.runtime._steppingInterval) {
                console.log('[Kiosk] VM not running, starting first...');
                window.vm.start();
            }
            window.vm.greenFlag();
            break;
            
        case 'stopAll':
            console.log('[Kiosk] Stopping project');
            window.vm.stopAll();
            break;
            
        case 'getStatus':
            if (event.source) {
                event.source.postMessage({
                    type: 'status',
                    running: window.vm.runtime.threads.length > 0
                }, '*');
            }
            break;
    }
});

console.log('[Kiosk] Player with Kiosk support loaded');
