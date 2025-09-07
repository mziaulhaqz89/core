/*
 * ATTENTION: An "eval-source-map" devtool has been used.
 * This devtool is neither made for production nor for readable output files.
 * It uses "eval()" calls to create a separate source file with attached SourceMaps in the browser devtools.
 * If you are trying to read the output file, select a different devtool (https://webpack.js.org/configuration/devtool/)
 * or disable the default devtool with "devtool: false".
 * If you are looking for production-ready output files, see mode: "production" (https://webpack.js.org/configuration/mode/).
 */
var cds;
/******/ (() => { // webpackBootstrap
/******/ 	"use strict";
/******/ 	var __webpack_modules__ = ({

/***/ "./src/Forms/AccountForm.ts":
/*!**********************************!*\
  !*** ./src/Forms/AccountForm.ts ***!
  \**********************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

eval("{__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   AccountForm: () => (/* binding */ AccountForm)\n/* harmony export */ });\n/* harmony import */ var _constants_EntityAttributes__WEBPACK_IMPORTED_MODULE_0__ = __webpack_require__(/*! ../constants/EntityAttributes */ \"./src/constants/EntityAttributes.ts\");\nvar __awaiter = (undefined && undefined.__awaiter) || function (thisArg, _arguments, P, generator) {\n    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }\n    return new (P || (P = Promise))(function (resolve, reject) {\n        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }\n        function rejected(value) { try { step(generator[\"throw\"](value)); } catch (e) { reject(e); } }\n        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }\n        step((generator = generator.apply(thisArg, _arguments || [])).next());\n    });\n};\n// Using @types/xrm - no imports needed, Xrm is globally available\n\nclass AccountForm {\n    static onLoad(context) {\n        return __awaiter(this, void 0, void 0, function* () {\n            context.getFormContext().getAttribute(_constants_EntityAttributes__WEBPACK_IMPORTED_MODULE_0__.AccountAttributes.WebSiteURL).addOnChange(AccountForm.onWebsiteChanged);\n        });\n    }\n    static onWebsiteChanged(context) {\n        const formContext = context.getFormContext();\n        const websiteAttribute = formContext.getAttribute(_constants_EntityAttributes__WEBPACK_IMPORTED_MODULE_0__.AccountAttributes.WebSiteURL);\n        const websiteRegex = /^(https?:\\/\\/)?([\\w\\d]+\\.)?[\\w\\d]+\\.\\w+\\/?.+$/g;\n        let isValid = true;\n        if (websiteAttribute && websiteAttribute.getValue()) {\n            const match = websiteAttribute.getValue().match(websiteRegex);\n            isValid = match != null;\n        }\n        websiteAttribute.controls.forEach((c) => {\n            if (isValid) {\n                c.clearNotification(_constants_EntityAttributes__WEBPACK_IMPORTED_MODULE_0__.AccountAttributes.WebSiteURL);\n            }\n            else {\n                c.setNotification(\"Hi, This is Invalid Website Address!\", _constants_EntityAttributes__WEBPACK_IMPORTED_MODULE_0__.AccountAttributes.WebSiteURL);\n            }\n        });\n    }\n}\n//# sourceURL=[module]\n//# sourceMappingURL=data:application/json;charset=utf-8;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiLi9zcmMvRm9ybXMvQWNjb3VudEZvcm0udHMiLCJtYXBwaW5ncyI6Ijs7Ozs7Ozs7Ozs7Ozs7QUFBQSxrRUFBa0U7QUFDQTtBQUUzRCxNQUFNLFdBQVc7SUFDdEIsTUFBTSxDQUFPLE1BQU0sQ0FBQyxPQUFnQzs7WUFDbEQsT0FBTyxDQUFDLGNBQWMsRUFBRSxDQUFDLFlBQVksQ0FBQywwRUFBaUIsQ0FBQyxVQUFVLENBQUMsQ0FBQyxXQUFXLENBQUMsV0FBVyxDQUFDLGdCQUFnQixDQUFDLENBQUM7UUFDaEgsQ0FBQztLQUFBO0lBRUQsTUFBTSxDQUFDLGdCQUFnQixDQUFDLE9BQWdDO1FBQ3RELE1BQU0sV0FBVyxHQUFHLE9BQU8sQ0FBQyxjQUFjLEVBQUUsQ0FBQztRQUM3QyxNQUFNLGdCQUFnQixHQUFHLFdBQVcsQ0FBQyxZQUFZLENBQUMsMEVBQWlCLENBQUMsVUFBVSxDQUFtQyxDQUFDO1FBQ2xILE1BQU0sWUFBWSxHQUFHLGdEQUFnRCxDQUFDO1FBRXRFLElBQUksT0FBTyxHQUFHLElBQUksQ0FBQztRQUNuQixJQUFJLGdCQUFnQixJQUFJLGdCQUFnQixDQUFDLFFBQVEsRUFBRSxFQUFFLENBQUM7WUFDcEQsTUFBTSxLQUFLLEdBQUcsZ0JBQWdCLENBQUMsUUFBUSxFQUFFLENBQUMsS0FBSyxDQUFDLFlBQVksQ0FBQyxDQUFDO1lBQzlELE9BQU8sR0FBRyxLQUFLLElBQUksSUFBSSxDQUFDO1FBQzFCLENBQUM7UUFFRCxnQkFBZ0IsQ0FBQyxRQUFRLENBQUMsT0FBTyxDQUFDLENBQUMsQ0FBQyxFQUFFLEVBQUU7WUFDdEMsSUFBSSxPQUFPLEVBQUUsQ0FBQztnQkFDWCxDQUFnQyxDQUFDLGlCQUFpQixDQUFDLDBFQUFpQixDQUFDLFVBQVUsQ0FBQyxDQUFDO1lBQ3BGLENBQUM7aUJBQU0sQ0FBQztnQkFDTCxDQUFnQyxDQUFDLGVBQWUsQ0FDL0Msc0NBQXNDLEVBQ3RDLDBFQUFpQixDQUFDLFVBQVUsQ0FDN0IsQ0FBQztZQUNKLENBQUM7UUFDSCxDQUFDLENBQUMsQ0FBQztJQUNMLENBQUM7Q0FDRiIsInNvdXJjZXMiOlsid2VicGFjazovL2Nkcy8uL3NyYy9Gb3Jtcy9BY2NvdW50Rm9ybS50cz9mYTdhIl0sInNvdXJjZXNDb250ZW50IjpbIi8vIFVzaW5nIEB0eXBlcy94cm0gLSBubyBpbXBvcnRzIG5lZWRlZCwgWHJtIGlzIGdsb2JhbGx5IGF2YWlsYWJsZVxyXG5pbXBvcnQgeyBBY2NvdW50QXR0cmlidXRlcyB9IGZyb20gXCIuLi9jb25zdGFudHMvRW50aXR5QXR0cmlidXRlc1wiO1xyXG5cclxuZXhwb3J0IGNsYXNzIEFjY291bnRGb3JtIHtcclxuICBzdGF0aWMgYXN5bmMgb25Mb2FkKGNvbnRleHQ6IFhybS5FdmVudHMuRXZlbnRDb250ZXh0KTogUHJvbWlzZTx2b2lkPiB7XHJcbiAgICBjb250ZXh0LmdldEZvcm1Db250ZXh0KCkuZ2V0QXR0cmlidXRlKEFjY291bnRBdHRyaWJ1dGVzLldlYlNpdGVVUkwpLmFkZE9uQ2hhbmdlKEFjY291bnRGb3JtLm9uV2Vic2l0ZUNoYW5nZWQpO1xyXG4gIH1cclxuXHJcbiAgc3RhdGljIG9uV2Vic2l0ZUNoYW5nZWQoY29udGV4dDogWHJtLkV2ZW50cy5FdmVudENvbnRleHQpOiB2b2lkIHtcclxuICAgIGNvbnN0IGZvcm1Db250ZXh0ID0gY29udGV4dC5nZXRGb3JtQ29udGV4dCgpO1xyXG4gICAgY29uc3Qgd2Vic2l0ZUF0dHJpYnV0ZSA9IGZvcm1Db250ZXh0LmdldEF0dHJpYnV0ZShBY2NvdW50QXR0cmlidXRlcy5XZWJTaXRlVVJMKSBhcyBYcm0uQXR0cmlidXRlcy5TdHJpbmdBdHRyaWJ1dGU7XHJcbiAgICBjb25zdCB3ZWJzaXRlUmVnZXggPSAvXihodHRwcz86XFwvXFwvKT8oW1xcd1xcZF0rXFwuKT9bXFx3XFxkXStcXC5cXHcrXFwvPy4rJC9nO1xyXG5cclxuICAgIGxldCBpc1ZhbGlkID0gdHJ1ZTtcclxuICAgIGlmICh3ZWJzaXRlQXR0cmlidXRlICYmIHdlYnNpdGVBdHRyaWJ1dGUuZ2V0VmFsdWUoKSkge1xyXG4gICAgICBjb25zdCBtYXRjaCA9IHdlYnNpdGVBdHRyaWJ1dGUuZ2V0VmFsdWUoKS5tYXRjaCh3ZWJzaXRlUmVnZXgpO1xyXG4gICAgICBpc1ZhbGlkID0gbWF0Y2ggIT0gbnVsbDtcclxuICAgIH1cclxuXHJcbiAgICB3ZWJzaXRlQXR0cmlidXRlLmNvbnRyb2xzLmZvckVhY2goKGMpID0+IHtcclxuICAgICAgaWYgKGlzVmFsaWQpIHtcclxuICAgICAgICAoYyBhcyBYcm0uQ29udHJvbHMuU3RyaW5nQ29udHJvbCkuY2xlYXJOb3RpZmljYXRpb24oQWNjb3VudEF0dHJpYnV0ZXMuV2ViU2l0ZVVSTCk7XHJcbiAgICAgIH0gZWxzZSB7XHJcbiAgICAgICAgKGMgYXMgWHJtLkNvbnRyb2xzLlN0cmluZ0NvbnRyb2wpLnNldE5vdGlmaWNhdGlvbihcclxuICAgICAgICAgIFwiSGksIFRoaXMgaXMgSW52YWxpZCBXZWJzaXRlIEFkZHJlc3MhXCIsXHJcbiAgICAgICAgICBBY2NvdW50QXR0cmlidXRlcy5XZWJTaXRlVVJMLFxyXG4gICAgICAgICk7XHJcbiAgICAgIH1cclxuICAgIH0pO1xyXG4gIH1cclxufVxyXG4iXSwibmFtZXMiOltdLCJzb3VyY2VSb290IjoiIn0=\n//# sourceURL=webpack-internal:///./src/Forms/AccountForm.ts\n\n}");

/***/ }),

/***/ "./src/constants/EntityAttributes.ts":
/*!*******************************************!*\
  !*** ./src/constants/EntityAttributes.ts ***!
  \*******************************************/
/***/ ((__unused_webpack_module, __webpack_exports__, __webpack_require__) => {

eval("{__webpack_require__.r(__webpack_exports__);\n/* harmony export */ __webpack_require__.d(__webpack_exports__, {\n/* harmony export */   AccountAttributes: () => (/* binding */ AccountAttributes),\n/* harmony export */   ContactAttributes: () => (/* binding */ ContactAttributes),\n/* harmony export */   OpportunityAttributes: () => (/* binding */ OpportunityAttributes)\n/* harmony export */ });\n// Entity attribute logical names for type safety\nconst AccountAttributes = {\n    WebSiteURL: \"websiteurl\",\n    Name: \"name\",\n    AccountNumber: \"accountnumber\",\n    PrimaryContactId: \"primarycontactid\",\n    // Add more as needed\n};\nconst ContactAttributes = {\n    FirstName: \"firstname\",\n    LastName: \"lastname\",\n    EmailAddress1: \"emailaddress1\",\n    // Add more as needed\n};\nconst OpportunityAttributes = {\n    Name: \"name\",\n    EstimatedValue: \"estimatedvalue\",\n    CustomerId: \"customerid\",\n    // Add more as needed\n};\n//# sourceURL=[module]\n//# sourceMappingURL=data:application/json;charset=utf-8;base64,eyJ2ZXJzaW9uIjozLCJmaWxlIjoiLi9zcmMvY29uc3RhbnRzL0VudGl0eUF0dHJpYnV0ZXMudHMiLCJtYXBwaW5ncyI6Ijs7Ozs7O0FBQUEsaURBQWlEO0FBQzFDLE1BQU0saUJBQWlCLEdBQUc7SUFDL0IsVUFBVSxFQUFFLFlBQVk7SUFDeEIsSUFBSSxFQUFFLE1BQU07SUFDWixhQUFhLEVBQUUsZUFBZTtJQUM5QixnQkFBZ0IsRUFBRSxrQkFBa0I7SUFDcEMscUJBQXFCO0NBQ2IsQ0FBQztBQUVKLE1BQU0saUJBQWlCLEdBQUc7SUFDL0IsU0FBUyxFQUFFLFdBQVc7SUFDdEIsUUFBUSxFQUFFLFVBQVU7SUFDcEIsYUFBYSxFQUFFLGVBQWU7SUFDOUIscUJBQXFCO0NBQ2IsQ0FBQztBQUVKLE1BQU0scUJBQXFCLEdBQUc7SUFDbkMsSUFBSSxFQUFFLE1BQU07SUFDWixjQUFjLEVBQUUsZ0JBQWdCO0lBQ2hDLFVBQVUsRUFBRSxZQUFZO0lBQ3hCLHFCQUFxQjtDQUNiLENBQUMiLCJzb3VyY2VzIjpbIndlYnBhY2s6Ly9jZHMvLi9zcmMvY29uc3RhbnRzL0VudGl0eUF0dHJpYnV0ZXMudHM/Y2UzYSJdLCJzb3VyY2VzQ29udGVudCI6WyIvLyBFbnRpdHkgYXR0cmlidXRlIGxvZ2ljYWwgbmFtZXMgZm9yIHR5cGUgc2FmZXR5XHJcbmV4cG9ydCBjb25zdCBBY2NvdW50QXR0cmlidXRlcyA9IHtcclxuICBXZWJTaXRlVVJMOiBcIndlYnNpdGV1cmxcIixcclxuICBOYW1lOiBcIm5hbWVcIixcclxuICBBY2NvdW50TnVtYmVyOiBcImFjY291bnRudW1iZXJcIixcclxuICBQcmltYXJ5Q29udGFjdElkOiBcInByaW1hcnljb250YWN0aWRcIixcclxuICAvLyBBZGQgbW9yZSBhcyBuZWVkZWRcclxufSBhcyBjb25zdDtcclxuXHJcbmV4cG9ydCBjb25zdCBDb250YWN0QXR0cmlidXRlcyA9IHtcclxuICBGaXJzdE5hbWU6IFwiZmlyc3RuYW1lXCIsXHJcbiAgTGFzdE5hbWU6IFwibGFzdG5hbWVcIixcclxuICBFbWFpbEFkZHJlc3MxOiBcImVtYWlsYWRkcmVzczFcIixcclxuICAvLyBBZGQgbW9yZSBhcyBuZWVkZWRcclxufSBhcyBjb25zdDtcclxuXHJcbmV4cG9ydCBjb25zdCBPcHBvcnR1bml0eUF0dHJpYnV0ZXMgPSB7XHJcbiAgTmFtZTogXCJuYW1lXCIsXHJcbiAgRXN0aW1hdGVkVmFsdWU6IFwiZXN0aW1hdGVkdmFsdWVcIixcclxuICBDdXN0b21lcklkOiBcImN1c3RvbWVyaWRcIixcclxuICAvLyBBZGQgbW9yZSBhcyBuZWVkZWRcclxufSBhcyBjb25zdDtcclxuXHJcbi8vIFR5cGUgaGVscGVycyBmb3IgYXV0b2NvbXBsZXRlIGFuZCB0eXBlIHNhZmV0eVxyXG5leHBvcnQgdHlwZSBBY2NvdW50QXR0cmlidXRlS2V5ID0ga2V5b2YgdHlwZW9mIEFjY291bnRBdHRyaWJ1dGVzO1xyXG5leHBvcnQgdHlwZSBDb250YWN0QXR0cmlidXRlS2V5ID0ga2V5b2YgdHlwZW9mIENvbnRhY3RBdHRyaWJ1dGVzO1xyXG5leHBvcnQgdHlwZSBPcHBvcnR1bml0eUF0dHJpYnV0ZUtleSA9IGtleW9mIHR5cGVvZiBPcHBvcnR1bml0eUF0dHJpYnV0ZXM7XHJcbiJdLCJuYW1lcyI6W10sInNvdXJjZVJvb3QiOiIifQ==\n//# sourceURL=webpack-internal:///./src/constants/EntityAttributes.ts\n\n}");

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __webpack_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		__webpack_modules__[moduleId](module, module.exports, __webpack_require__);
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/define property getters */
/******/ 	(() => {
/******/ 		// define getter functions for harmony exports
/******/ 		__webpack_require__.d = (exports, definition) => {
/******/ 			for(var key in definition) {
/******/ 				if(__webpack_require__.o(definition, key) && !__webpack_require__.o(exports, key)) {
/******/ 					Object.defineProperty(exports, key, { enumerable: true, get: definition[key] });
/******/ 				}
/******/ 			}
/******/ 		};
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/hasOwnProperty shorthand */
/******/ 	(() => {
/******/ 		__webpack_require__.o = (obj, prop) => (Object.prototype.hasOwnProperty.call(obj, prop))
/******/ 	})();
/******/ 	
/******/ 	/* webpack/runtime/make namespace object */
/******/ 	(() => {
/******/ 		// define __esModule on exports
/******/ 		__webpack_require__.r = (exports) => {
/******/ 			if(typeof Symbol !== 'undefined' && Symbol.toStringTag) {
/******/ 				Object.defineProperty(exports, Symbol.toStringTag, { value: 'Module' });
/******/ 			}
/******/ 			Object.defineProperty(exports, '__esModule', { value: true });
/******/ 		};
/******/ 	})();
/******/ 	
/************************************************************************/
/******/ 	
/******/ 	// startup
/******/ 	// Load entry module and return exports
/******/ 	// This entry module can't be inlined because the eval-source-map devtool is used.
/******/ 	var __webpack_exports__ = __webpack_require__("./src/Forms/AccountForm.ts");
/******/ 	cds = __webpack_exports__;
/******/ 	
/******/ })()
;